/*
 * L'SPACE Mars Polar Rover - Thermal Control Subsystem (TCS)
 * SysML v2 model, part 1 of 5: Architecture
 *
 * Structure (block definitions), interfaces (ports and interface
 * definitions) and the rover-level context that shows how the TCS connects
 * to the payload, power, avionics, chassis and the Mars environment.
 *
 * Values marked "from analysis" come from analysis/results/*.csv, produced
 * by the MATLAB model in analysis/.
 */
package LSpaceThermal_Architecture {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    /* ---------------------------------------------------------------
     * Interface definitions
     * --------------------------------------------------------------- */
    doc /* Ports carry heat, electrical power, temperature telemetry and heater
         * commands. Heat flow is modelled as a power quantity across a port. */

    port def HeatPort {
        doc /* Conductive or radiative heat exchange across a boundary. */
        inout attribute heatFlow : PowerValue;
    }
    port def DCPowerPort {
        doc /* Unregulated 28 V class DC bus (voltage level TBD with EPS). */
        in attribute power : PowerValue;
    }
    port def TemperatureTelemetryPort {
        out attribute temperature : ThermodynamicTemperatureValue;
    }
    port def HeaterCommandPort {
        in attribute heaterOn : Boolean;
    }

    interface def ConductiveInterface {
        doc /* A thermal path characterised by its conductance G [W/K]. */
        end warmSide : HeatPort;
        end coldSide : HeatPort;
        attribute conductance_W_per_K : Real;
    }
    interface def PowerInterface {
        end source : ~DCPowerPort;
        end load : DCPowerPort;
    }
    interface def TelemetryInterface {
        end sensor : TemperatureTelemetryPort;
        end processor : ~TemperatureTelemetryPort;
    }
    interface def HeaterCommandInterface {
        end controller : ~HeaterCommandPort;
        end switch : HeaterCommandPort;
    }

    /* ---------------------------------------------------------------
     * TCS component definitions
     * --------------------------------------------------------------- */
    part def AerogelInsulation {
        doc /* Opacified silica aerogel panels lining the WEB walls. Chosen in
             * trade T1: MLI loses most of its performance in the 5-8 torr CO2
             * atmosphere because gas conducts between the layers. */
        attribute thickness :> ISQ::length = 0.075 [m];
        attribute conductivity_W_per_mK : Real = 0.010;
        attribute density_kg_per_m3 : Real = 15.0;
        attribute mass :> ISQ::mass = 1.19 [kg];     // from analysis, trade T1
    }
    part def ExteriorCoating {
        doc /* AZ-1000-ECB conductive black paint (the 2023 PDR choice,
             * re-justified by trade T2: lowest heater energy, dust tolerant). */
        attribute solarAbsorptance : Real = 0.97;
        attribute irEmittance : Real = 0.89;
    }
    part def WarmElectronicsBox {
        doc /* Insulated enclosure (inner envelope 0.50 x 0.30 x 0.25 m) holding the
             * science payload, avionics, battery and PCM module. */
        part insulation : AerogelInsulation;
        part coating : ExteriorCoating;
        attribute innerLength :> ISQ::length = 0.50 [m];
        attribute innerWidth :> ISQ::length = 0.30 [m];
        attribute innerHeight :> ISQ::length = 0.25 [m];
        attribute insulationConductance_W_per_K : Real = 0.135;  // from analysis
        port interiorHeat : HeatPort;
        port exteriorHeat : HeatPort;
    }
    part def FilmHeater {
        doc /* Polyimide film heater bonded to a mounting plate. */
        attribute ratedPower :> ISQ::power;
        port powerIn : DCPowerPort;
        port command : HeaterCommandPort;
        port heatOut : HeatPort;
    }
    part def OverTemperatureCutoff {
        doc /* Normally-closed thermostat in series with each heater string.
             * Opens at 308.15 K so a heater stuck ON cannot overheat the payload
             * (failure case F4: 423 K without it, 308 K with it). */
        attribute openTemp : ThermodynamicTemperatureValue = 308.15 [K];
    }
    part def HeaterString {
        doc /* One complete heater circuit: payload-plate and battery elements.
             * Two identical strings are installed (primary + redundant). */
        part payloadHeater : FilmHeater { attribute :>> ratedPower = 20.0 [W]; }
        part batteryHeater : FilmHeater { attribute :>> ratedPower = 10.0 [W]; }
        part cutoff : OverTemperatureCutoff;
        attribute stringPower :> ISQ::power = 30.0 [W];   // sized in run_steady_state
    }
    part def MechanicalThermostat {
        doc /* Bimetallic survival thermostat, closes at 265.15 K, opens at
             * 267.15 K (2 K above the 263.15 K survival limit). Works with
             * flight software off (fault tolerance). */
        attribute closeTemp : ThermodynamicTemperatureValue = 265.15 [K];
        attribute openTemp : ThermodynamicTemperatureValue = 267.15 [K];
    }
    part def PlatinumRTD {
        doc /* Platinum resistance thermometer, +/-0.5 K accuracy. */
        attribute accuracy :> ISQ::temperature = 0.5 [K];
        port reading : TemperatureTelemetryPort;
    }
    part def PCMModule {
        doc /* Finned aluminium container of n-octadecane (melts at 301.13 K,
             * 237 kJ/kg). Absorbs the 38 W scan heat at constant temperature. */
        attribute pcmMass :> ISQ::mass = 1.0 [kg];       // trade T3
        attribute containerMass :> ISQ::mass = 0.4 [kg];
        attribute meltTemp : ThermodynamicTemperatureValue = 301.13 [K];
        port heat : HeatPort;
    }
    part def IsolationStandoff {
        doc /* G-10 fibreglass standoff, 10 mm diameter x 25 mm, between WEB and chassis. */
        attribute conductance_W_per_K : Real = 0.00091;
    }

    part def ThermalControlSubsystem {
        doc /* The system of interest. Passive elements (insulation, coating, PCM,
             * standoffs) plus active control (heaters, thermostats, sensors).
             * The control algorithm runs in C&DH flight software. */
        part web : WarmElectronicsBox;
        part primaryHeaters : HeaterString;
        part redundantHeaters : HeaterString;
        part survivalThermostats[2] : MechanicalThermostat;
        part sensors[4] : PlatinumRTD;
        part pcm : PCMModule;
        part standoffs[4] : IsolationStandoff;

        attribute payloadTemperature : ThermodynamicTemperatureValue;
        attribute heaterEnergyPerSol_Wh : Real;
        attribute heaterDutyCycle : Real;
        attribute totalMass :> ISQ::mass = 3.2 [kg];   // see design doc mass budget

        port powerIn : DCPowerPort;
        port telemetry[4] : TemperatureTelemetryPort;
        port heaterCommand : HeaterCommandPort;
    }

    /* ---------------------------------------------------------------
     * External elements (owned by other subsystems)
     * --------------------------------------------------------------- */
    part def ScienceInstruments {
        doc /* MSolo mass spectrometer (6.0 kg, 35 W scanning) and neutron
             * spectrometer (1.6 kg, 1.5 W) [2023 PDR]. */
        attribute scanDissipation :> ISQ::power = 38.0 [W];
        attribute operatingMin : ThermodynamicTemperatureValue = 293.15 [K];
        attribute operatingMax : ThermodynamicTemperatureValue = 303.15 [K];
        port heat : HeatPort;
    }
    part def LiIonBattery {
        attribute usableEnergy_Wh : Real = 150.0;   // assumption A-16, PDR TBD
        port heat : HeatPort;
    }
    part def ElectricalPowerSubsystem {
        doc /* Two 0.8 x 0.8 m triple-junction panels tilted 35 deg + Li-ion battery. */
        part battery : LiIonBattery;
        port heaterBus : ~DCPowerPort;
    }
    part def CommandAndDataHandling {
        doc /* Hosts the thermal control software (see 03_Behavior). */
        port temperatureIn[4] : ~TemperatureTelemetryPort;
        port heaterCommandOut : ~HeaterCommandPort;
    }
    part def Chassis {
        doc /* Aluminium frame with polycarbonate panels; sits at air temperature. */
        port heatSink : HeatPort;
    }
    part def MarsPolarEnvironment {
        doc /* 85 N, northern summer (Ls 90-125). Air 184-253 K design range,
             * optical depth 0.3-3.0, convection 0.4-4.0 W/m2K. */
        port surroundings : HeatPort;
    }
    part def Rover;

    /* ---------------------------------------------------------------
     * Context: the TCS inside the L'SPACE rover
     * --------------------------------------------------------------- */
    part lspaceRover : Rover {
        part tcs : ThermalControlSubsystem;
        part payload : ScienceInstruments;
        part eps : ElectricalPowerSubsystem;
        part cdh : CommandAndDataHandling;
        part chassis : Chassis;

        interface payloadToWeb : ConductiveInterface
            connect warmSide ::> payload.heat to coldSide ::> tcs.web.interiorHeat;
        interface batteryToWeb : ConductiveInterface
            connect warmSide ::> eps.battery.heat to coldSide ::> tcs.web.interiorHeat;
        interface webToChassis : ConductiveInterface
            connect warmSide ::> tcs.web.interiorHeat to coldSide ::> chassis.heatSink {
            attribute :>> conductance_W_per_K = 0.0189;   // standoffs + harness + aperture
        }
        interface heaterPower : PowerInterface
            connect source ::> eps.heaterBus to load ::> tcs.powerIn;
        interface heaterCmd : HeaterCommandInterface
            connect controller ::> cdh.heaterCommandOut to switch ::> tcs.heaterCommand;
    }
    part marsEnvironment : MarsPolarEnvironment;

    connection webToEnvironment : ConductiveInterface
        connect warmSide ::> lspaceRover.tcs.web.exteriorHeat to coldSide ::> marsEnvironment.surroundings;
}
