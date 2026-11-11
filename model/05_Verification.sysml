/*
 * L'SPACE Mars Polar Rover - Thermal Control Subsystem (TCS)
 * SysML v2 model, part 5 of 5: Verification
 *
 * One verification case per requirement, with its method (analysis,
 * inspection, demonstration or test) and status. "Closed by analysis"
 * cases are backed by analysis/results/*.csv. Test cases are PROPOSED: no
 * hardware was built or tested for this project.
 */
package LSpaceThermal_Verification {
    private import VerificationCases::*;
    private import LSpaceThermal_Architecture::*;
    private import LSpaceThermal_Requirements::*;

    verification def ThermalVerification {
        subject tcs : ThermalControlSubsystem;
    }

    /* ---------------- closed by analysis ---------------- */
    verification vcPayloadOperating : ThermalVerification {
        doc /* Transient design cases: scan window 295.3-301.1 K, hot and cold.
             * Status: CLOSED BY ANALYSIS (run_transient_cases). */
        objective { verify tcsSpecification.payloadOperating; }
        metadata VerificationMethod { kind = VerificationMethodKind::analyze; }
    }
    verification vcScanHeat : ThermalVerification {
        doc /* Trade T3: 1.0 kg PCM, 2 h scan, hot case, peak 301.1 K, melt 75 %.
             * Status: CLOSED BY ANALYSIS (run_trade_studies). */
        objective { verify tcsSpecification.scanHeat; }
        metadata VerificationMethod { kind = VerificationMethodKind::analyze; }
    }
    verification vcEnergy : ThermalVerification {
        doc /* Cold 176 Wh/sol (limit 200); storm 195 Wh/sol (limit 250).
             * Status: CLOSED BY ANALYSIS. */
        objective { verify tcsSpecification.energy; }
        metadata VerificationMethod { kind = VerificationMethodKind::analyze; }
    }
    verification vcDutyCycle : ThermalVerification {
        doc /* Worst cold loss 16.4 W; 30 W x 0.70 x 0.81 = 17.0 W >= 16.4 W.
             * Status: CLOSED BY ANALYSIS (run_steady_state). */
        objective { verify tcsSpecification.dutyCycle; }
        metadata VerificationMethod { kind = VerificationMethodKind::analyze; }
    }
    verification vcNoSolar : ThermalVerification {
        doc /* 150 Wh / (7.9 W heater + 1.0 W load) = 16.8 h >= 12 h.
             * Status: CLOSED BY ANALYSIS; depends on battery assumption A-16. */
        objective { verify tcsSpecification.noSolar; }
        metadata VerificationMethod { kind = VerificationMethodKind::analyze; }
    }
    verification vcEnvironment : ThermalVerification {
        doc /* Hot, cold and storm cases bound the design environment.
             * Status: CLOSED BY ANALYSIS. */
        objective { verify tcsSpecification.environment; }
        metadata VerificationMethod { kind = VerificationMethodKind::analyze; }
    }

    verification vcStuckHeater : ThermalVerification {
        doc /* Failure case F4: string stuck ON in hot standby peaks at 308.2 K with
             * the 308.15 K cutoff (423 K without). Status: CLOSED BY ANALYSIS;
             * cutoff set point to be confirmed by test. */
        objective { verify tcsSpecification.stuckHeater; }
        metadata VerificationMethod { kind = VerificationMethodKind::analyze; }
    }

    /* ---------------- demonstration ---------------- */
    verification vcFaultResponse : ThermalVerification {
        doc /* PROPOSED: flight-software test bench - fail the active string
             * and show detection and switchover within 4 h. */
        objective { verify tcsSpecification.faultResponse; }
        metadata VerificationMethod { kind = VerificationMethodKind::demo; }
    }

    /* ---------------- inspection ---------------- */
    verification vcRedundancy : ThermalVerification {
        doc /* Inspect heater schematic: two independent strings, separate switches. */
        objective { verify tcsSpecification.redundancy; }
        metadata VerificationMethod { kind = VerificationMethodKind::inspect; }
    }
    verification vcMass : ThermalVerification {
        doc /* Weigh flight hardware against the 3.5 kg allocation (estimate 3.2 kg). */
        objective { verify tcsSpecification.mass; }
        metadata VerificationMethod { kind = VerificationMethodKind::inspect; }
    }
    verification vcSensing : ThermalVerification {
        doc /* Inspect sensor layout and calibration certificates (+/-0.5 K). */
        objective { verify tcsSpecification.sensing; }
        metadata VerificationMethod { kind = VerificationMethodKind::inspect; }
    }

    /* ---------------- proposed tests (not performed) ---------------- */
    verification vcSurvivalThermalBalance : ThermalVerification {
        doc /* PROPOSED: thermal balance test of the WEB in a Mars simulation
             * chamber (CO2 at 600-1000 Pa, cold walls at 184 K) with flight
             * software off. Pass: interior >= 263.15 K on thermostats alone.
             * Also correlates the model (G_ins, G_leak) - this is what would
             * turn "verified" into "validated". */
        objective { verify tcsSpecification.survival; }
        metadata VerificationMethod { kind = VerificationMethodKind::test; }
    }
    verification vcHeaterFailureTest : ThermalVerification {
        doc /* PROPOSED: in the Mars chamber, (a) disable one string and run the
             * warm-up on the other at 90 % bus voltage (expect scan-start >= 293.15 K,
             * analysis F1: 295.6 K); (b) force a string ON and confirm the cutoff
             * opens near 308 K (analysis F4). */
        objective {
            verify tcsSpecification.redundancy;
            verify tcsSpecification.stuckHeater;
        }
        metadata VerificationMethod { kind = VerificationMethodKind::test; }
    }
    verification vcThermalCycling : ThermalVerification {
        doc /* PROPOSED: thermal cycling of heaters, thermostats, PCM module and
             * aerogel panels, 184-303 K, 3x mission sols, workmanship check. */
        objective { verify tcsSpecification.payloadOperating; }
        metadata VerificationMethod { kind = VerificationMethodKind::test; }
    }
}
