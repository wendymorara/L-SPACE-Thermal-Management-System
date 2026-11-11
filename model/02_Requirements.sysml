/*
 * L'SPACE Mars Polar Rover - Thermal Control Subsystem (TCS)
 * SysML v2 model, part 2 of 5: Requirements
 *
 * PDR_2023 holds the four thermal requirements as written in the 2023 PDR.
 * TCS_Requirements holds the revised, verifiable subsystem requirements.
 * Each revised requirement is derived from a PDR parent (#derivation) and
 * satisfied by the TCS design (satisfy).
 */
package LSpaceThermal_Requirements {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import RequirementDerivation::*;
    private import LSpaceThermal_Architecture::*;

    /* ---------------------------------------------------------------
     * 2023 PDR requirements (verbatim intent, for traceability)
     * --------------------------------------------------------------- */
    package PDR_2023 {
        requirement <'TSS-1'> protectPayload {
            doc /* System shall protect the payload from extreme temperatures and
                 * temperature fluctuations on Mars. */
        }
        requirement <'TSS-2'> heatingSystem {
            doc /* System shall have a heating system to maintain the temperature of
                 * the payload and other critical systems during cold periods on Mars. */
        }
        requirement <'TSS-3'> operatingTemperature {
            doc /* System shall maintain an operating temperature of about
                 * 293.15 K to 303.15 K. */
        }
        requirement <'TSS-4'> polarExtremes {
            doc /* System shall be able to withstand Mars north pole extreme
                 * temperatures of 133.15 K to 243.15 K. */
        }
    }

    /* ---------------------------------------------------------------
     * Revised TCS requirement definitions
     * --------------------------------------------------------------- */
    requirement def PayloadOperatingTemperature {
        doc /* The TCS shall maintain the science payload between 293.15 K and
             * 303.15 K from the start of each science scan to its end. */
        subject tcs : ThermalControlSubsystem;
        attribute minTemp : ThermodynamicTemperatureValue = 293.15 [K];
        attribute maxTemp : ThermodynamicTemperatureValue = 303.15 [K];
        require constraint {
            tcs.payloadTemperature >= minTemp and tcs.payloadTemperature <= maxTemp
        }
    }
    requirement def SurvivalTemperature {
        doc /* The TCS shall keep the WEB interior at or above 263.15 K at all times,
             * in every mode, including with flight software inactive. */
        subject tcs : ThermalControlSubsystem;
        attribute survivalMin : ThermodynamicTemperatureValue = 263.15 [K];
        require constraint { tcs.payloadTemperature >= survivalMin }
    }
    requirement def DesignEnvironment {
        doc /* The TCS shall meet its temperature requirements for air temperatures
             * of 184.15 K to 253.15 K, optical depth 0.3 to 3.0 and convection
             * coefficients of 0.4 to 4.0 W/m2K at 85 N during Ls 90 to 125. */
        subject tcs : ThermalControlSubsystem;
        attribute airMin : ThermodynamicTemperatureValue = 184.15 [K];
        attribute airMax : ThermodynamicTemperatureValue = 253.15 [K];
    }
    requirement def HeaterEnergyAllocation {
        doc /* Heater energy shall not exceed 200 Wh per sol in the cold design
             * case or 250 Wh per sol in the dust-storm survival case. */
        subject tcs : ThermalControlSubsystem;
        attribute maxColdWh : Real = 200.0;
        require constraint { tcs.heaterEnergyPerSol_Wh <= maxColdWh }
    }
    requirement def HeaterDutyCycle {
        doc /* Installed heater power shall give a duty cycle of no more than 70 %
             * in the worst cold case at minimum bus voltage. */
        subject tcs : ThermalControlSubsystem;
        attribute maxDuty : Real = 0.70;
        require constraint { tcs.heaterDutyCycle <= maxDuty }
    }
    requirement def HeaterRedundancy {
        doc /* The TCS shall provide two independent heater strings, each able to
             * meet HeaterDutyCycle on its own. */
        subject tcs : ThermalControlSubsystem;
    }
    requirement def TemperatureSensing {
        doc /* The TCS shall measure WEB interior temperature with at least two
             * sensors per heater zone, each accurate to +/-0.5 K. */
        subject tcs : ThermalControlSubsystem;
    }
    requirement def ScanHeatAbsorption {
        doc /* The TCS shall keep the payload at or below 303.15 K during a 2 h,
             * 38 W science scan in the hot design case. */
        subject tcs : ThermalControlSubsystem;
        attribute scanDuration :> ISQ::time = 2.0 [h];
        attribute scanPower :> ISQ::power = 38.0 [W];
    }
    requirement def MassAllocation {
        doc /* TCS mass shall not exceed 3.5 kg including PCM, heaters, sensors,
             * insulation and standoffs. */
        subject tcs : ThermalControlSubsystem;
        attribute maxMass :> ISQ::mass = 3.5 [kg];
        require constraint { tcs.totalMass <= maxMass }
    }
    requirement def NoSolarSurvival {
        doc /* With no solar input, the TCS shall hold the survival temperature for
             * at least 12 h on the usable battery energy. */
        subject tcs : ThermalControlSubsystem;
        attribute minHours : Real = 12.0;
    }

    requirement def StuckHeaterProtection {
        doc /* With any one heater string failed ON, the WEB interior shall not
             * exceed 313.15 K. (Derived from failure analysis F4.) */
        subject tcs : ThermalControlSubsystem;
        attribute maxTemp : ThermodynamicTemperatureValue = 313.15 [K];
    }
    requirement def HeaterFaultResponse {
        doc /* The TCS and C&DH shall detect a failed heater string and switch to
             * the redundant string within 4 h. (Derived from failure analysis F2:
             * 4.9 h from the survival set point to the 253 K battery limit.) */
        subject tcs : ThermalControlSubsystem;
        attribute maxResponseHours : Real = 4.0;
    }

    /* ---------------------------------------------------------------
     * Requirement usages (the specification)
     * --------------------------------------------------------------- */
    requirement tcsSpecification {
        subject tcs : ThermalControlSubsystem;
        requirement <'TCS-01'> payloadOperating : PayloadOperatingTemperature;
        requirement <'TCS-02'> survival : SurvivalTemperature;
        requirement <'TCS-03'> environment : DesignEnvironment;
        requirement <'TCS-04'> energy : HeaterEnergyAllocation;
        requirement <'TCS-05'> dutyCycle : HeaterDutyCycle;
        requirement <'TCS-06'> redundancy : HeaterRedundancy;
        requirement <'TCS-07'> sensing : TemperatureSensing;
        requirement <'TCS-08'> scanHeat : ScanHeatAbsorption;
        requirement <'TCS-09'> mass : MassAllocation;
        requirement <'TCS-10'> noSolar : NoSolarSurvival;
        requirement <'TCS-11'> stuckHeater : StuckHeaterProtection;
        requirement <'TCS-12'> faultResponse : HeaterFaultResponse;
    }

    /* ---------------------------------------------------------------
     * Derivation: PDR parent -> revised child
     * --------------------------------------------------------------- */
    #derivation connection d01 {
        end #original ::> PDR_2023::operatingTemperature;
        end #derive ::> tcsSpecification.payloadOperating;
        end #derive ::> tcsSpecification.scanHeat;
    }
    #derivation connection d02 {
        end #original ::> PDR_2023::protectPayload;
        end #derive ::> tcsSpecification.survival;
        end #derive ::> tcsSpecification.noSolar;
        end #derive ::> tcsSpecification.stuckHeater;
        end #derive ::> tcsSpecification.faultResponse;
    }
    #derivation connection d03 {
        end #original ::> PDR_2023::polarExtremes;
        end #derive ::> tcsSpecification.environment;
    }
    #derivation connection d04 {
        end #original ::> PDR_2023::heatingSystem;
        end #derive ::> tcsSpecification.energy;
        end #derive ::> tcsSpecification.dutyCycle;
        end #derive ::> tcsSpecification.redundancy;
        end #derive ::> tcsSpecification.sensing;
    }

    /* ---------------------------------------------------------------
     * Satisfaction: the design claims to meet the specification
     * --------------------------------------------------------------- */
    satisfy tcsSpecification by lspaceRover.tcs;
}
