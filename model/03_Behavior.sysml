/*
 * L'SPACE Mars Polar Rover - Thermal Control Subsystem (TCS)
 * SysML v2 model, part 3 of 5: Behavior
 *
 * - ThermalModes: the operating concept (concept B) as a state machine
 * - RegulateWebTemperature: the control function as an action flow
 * - Allocation of functions to physical components
 */
package LSpaceThermal_Behavior {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import LSpaceThermal_Architecture::*;

    /* ---------------------------------------------------------------
     * Signals (commands and events)
     * --------------------------------------------------------------- */
    item def WarmUpCommand {
        doc /* Sent by ground or the onboard sequence 6 h before a scheduled scan. */
    }
    item def ScanStart;
    item def ScanComplete;
    item def SetPointReached;
    item def DustStormAlert;
    item def StormCleared;
    item def SoftwareFault;
    item def SoftwareRecovered;

    /* ---------------------------------------------------------------
     * Operating modes (concept B)
     * --------------------------------------------------------------- */
    state def ThermalModes {
        doc /* Heater set points per mode:
             *   Standby   265.15 / 267.15 K (on / off)
             *   WarmUp    295.15 / 297.15 K, heaters at full 30 W until set point
             *   Science   295.15 / 297.15 K, PCM absorbs scan heat at 301.13 K
             *   Survival  265.15 / 267.15 K, minimum loads (dust storm)
             *   SafeHold  hardware thermostats only, software off */

        entry; then standby;

        state standby {
            doc /* Non-science sols (72 of 90). Hold survival set point. */
        }
        state warmUp {
            doc /* Pre-heat payload from ~265 K to 295 K (6 h lead covers one string
                 * at minimum bus voltage, failure case F1). */
        }
        state science {
            doc /* Scan in progress: 38 W internal dissipation, heater mostly off. */
        }
        state survival {
            doc /* Dust storm (tau ~ 3): science suspended, array output ~320 Wh/sol. */
        }
        state safeHold {
            doc /* Flight software inactive: mechanical thermostats hold 265 K. */
        }

        transition standby_to_warmUp
            first standby accept WarmUpCommand then warmUp;
        transition warmUp_to_science
            first warmUp accept ScanStart then science;
        transition science_to_standby
            first science accept ScanComplete then standby;
        transition standby_to_survival
            first standby accept DustStormAlert then survival;
        transition warmUp_to_survival
            first warmUp accept DustStormAlert then survival;
        transition science_to_survival
            first science accept DustStormAlert then survival;
        transition survival_to_standby
            first survival accept StormCleared then standby;
        transition standby_to_safeHold
            first standby accept SoftwareFault then safeHold;
        transition safeHold_to_standby
            first safeHold accept SoftwareRecovered then standby;
    }

    /* ---------------------------------------------------------------
     * Control function
     * --------------------------------------------------------------- */
    action def SenseTemperature {
        out temperature : ThermodynamicTemperatureValue;
    }
    action def ValidateReadings {
        doc /* Average the valid RTDs in a zone; flag a sensor that disagrees
             * with its pair by more than 2 K. */
        in temperature : ThermodynamicTemperatureValue;
        out zoneTemperature : ThermodynamicTemperatureValue;
    }
    action def ComputeHeaterCommand {
        doc /* Hysteresis (bang-bang) control around the mode set point. */
        in zoneTemperature : ThermodynamicTemperatureValue;
        out heaterOn : Boolean;
    }
    action def SwitchHeater {
        in heaterOn : Boolean;
    }
    action def ReportTelemetry {
        in zoneTemperature : ThermodynamicTemperatureValue;
    }

    action def RegulateWebTemperature {
        action sense : SenseTemperature;
        action validate : ValidateReadings;
        action compute : ComputeHeaterCommand;
        action actuate : SwitchHeater;
        action report : ReportTelemetry;

        flow sense.temperature to validate.temperature;
        flow validate.zoneTemperature to compute.zoneTemperature;
        flow validate.zoneTemperature to report.zoneTemperature;
        flow compute.heaterOn to actuate.heaterOn;

        first sense then validate;
        first validate then compute;
        first compute then actuate;
        first validate then report;
    }

    /* ---------------------------------------------------------------
     * Usage in the rover and functional allocation
     * --------------------------------------------------------------- */
    part thermalBehavior {
        doc /* Binds the behaviour to the rover context defined in 01_Architecture. */
        exhibit state modes : ThermalModes;
        perform action regulate : RegulateWebTemperature;
    }

    allocation def FunctionToComponent {
        end function : Actions::Action;
        end component : Parts::Part;
    }
    allocation senseAlloc : FunctionToComponent
        allocate thermalBehavior.regulate.sense to lspaceRover.tcs.sensors;
    allocation validateAlloc : FunctionToComponent
        allocate thermalBehavior.regulate.validate to lspaceRover.cdh;
    allocation computeAlloc : FunctionToComponent
        allocate thermalBehavior.regulate.compute to lspaceRover.cdh;
    allocation actuateAlloc : FunctionToComponent
        allocate thermalBehavior.regulate.actuate to lspaceRover.tcs.primaryHeaters;
    allocation reportAlloc : FunctionToComponent
        allocate thermalBehavior.regulate.report to lspaceRover.cdh;
}
