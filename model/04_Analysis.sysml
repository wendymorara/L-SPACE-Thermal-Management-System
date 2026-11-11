/*
 * L'SPACE Mars Polar Rover - Thermal Control Subsystem (TCS)
 * SysML v2 model, part 4 of 5: Analysis
 *
 * Captures the governing equations as calculation and constraint
 * definitions, the design-case analyses, and the insulation trade study.
 * The numbers are computed by the MATLAB model (analysis/); the values
 * recorded here are its outputs, so the model and the code stay traceable.
 */
package LSpaceThermal_Analysis {
    private import ScalarValues::*;
    private import RealFunctions::*;
    private import TradeStudies::*;
    private import LSpaceThermal_Architecture::*;

    /* ---------------------------------------------------------------
     * Governing equations (SI units: W, K, m, W/K)
     * --------------------------------------------------------------- */
    calc def InsulationConductance {
        doc /* Thick-shell conduction: G = k * sqrt(A_in * A_out) / t */
        in k : Real;
        in areaInner : Real;
        in areaOuter : Real;
        in thickness : Real;
        return : Real = k * sqrt(areaInner * areaOuter) / thickness;
    }
    calc def InteriorHeatLoss {
        doc /* Q_loss = G_ins (T_int - T_skin) + G_leak (T_int - T_air) */
        in G_ins : Real;
        in G_leak : Real;
        in T_int : Real;
        in T_skin : Real;
        in T_air : Real;
        return : Real = G_ins * (T_int - T_skin) + G_leak * (T_int - T_air);
    }
    calc def RequiredHeaterPower {
        doc /* P_req = max(Q_loss - Q_internal, 0) */
        in Q_loss : Real;
        in Q_internal : Real;
        return : Real = if Q_loss > Q_internal ? Q_loss - Q_internal else 0.0;
    }
    calc def PcmPlateauTime {
        doc /* Time the PCM holds its melt temperature: m * L / Q_net */
        in pcmMass : Real;
        in latentHeat : Real;
        in netHeating : Real;
        return : Real = pcmMass * latentHeat / netHeating;
    }
    constraint def HeaterSizingRule {
        doc /* Installed power at minimum bus voltage, run at no more than the
             * maximum duty cycle, must cover the worst-case required power. */
        in P_installed : Real;
        in P_required : Real;
        in maxDuty : Real;
        in busVoltageFactor : Real;
        P_installed * maxDuty * busVoltageFactor >= P_required
    }

    /* ---------------------------------------------------------------
     * Design-case analyses (results from analysis/results/)
     * --------------------------------------------------------------- */
    analysis def HeaterSizingAnalysis {
        subject tcs : ThermalControlSubsystem;
        objective {
            doc /* Size the heater strings for the cold design case
                 * (requirement TCS-05). */
        }
        in attribute P_worst_W : Real = 16.4;          // run_steady_state, cold worst-instantaneous
        in attribute maxDuty : Real = 0.70;
        in attribute busVoltageFactor : Real = 0.81;
        attribute P_installed_W : Real = 30.0;
        constraint rule : HeaterSizingRule {
            in P_installed = P_installed_W;
            in P_required = P_worst_W;
            in maxDuty = maxDuty;
            in busVoltageFactor = busVoltageFactor;
        }
        return P_min_W : Real = P_worst_W / (maxDuty * busVoltageFactor);   // 28.8 W
    }

    analysis def DesignCaseAnalysis {
        doc /* Transient two-node simulation of one design case (simulate_web.m). */
        subject tcs : ThermalControlSubsystem;
        attribute caseName : String;
        attribute scanTmin_K : Real;
        attribute scanTmax_K : Real;
        attribute heaterWhPerSol : Real;
        attribute pcmMeltFraction : Real;
    }

    analysis coldScienceSol : DesignCaseAnalysis {
        attribute :>> caseName = "Cold, science sol, concept B";
        attribute :>> scanTmin_K = 296.5;
        attribute :>> scanTmax_K = 301.1;
        attribute :>> heaterWhPerSol = 176.0;
        attribute :>> pcmMeltFraction = 0.63;
    }
    analysis coldStandbySol : DesignCaseAnalysis {
        attribute :>> caseName = "Cold, standby sol, concept B";
        attribute :>> heaterWhPerSol = 176.0;
    }
    analysis hotScienceSol : DesignCaseAnalysis {
        attribute :>> caseName = "Hot, science sol, concept B";
        attribute :>> scanTmin_K = 295.3;
        attribute :>> scanTmax_K = 301.1;
        attribute :>> heaterWhPerSol = 54.0;
        attribute :>> pcmMeltFraction = 0.75;
    }
    analysis dustStormSurvival : DesignCaseAnalysis {
        attribute :>> caseName = "Dust storm, survival";
        attribute :>> heaterWhPerSol = 195.0;
    }

    /* ---------------------------------------------------------------
     * Trade study T1: insulation (model-based selection)
     * --------------------------------------------------------------- */
    part def InsulationAlternative {
        attribute material : String;
        attribute thickness_mm : Real;
        attribute heaterAvg_W : Real;       // cold standby sol, concept B
        attribute insulationMass_kg : Real;
        attribute equivalentMass_kg : Real; // insulation + 0.19 kg per W of heater power
    }
    part aerogel50 : InsulationAlternative {
        attribute :>> material = "Silica aerogel";
        attribute :>> thickness_mm = 50.0;
        attribute :>> heaterAvg_W = 9.42;
        attribute :>> insulationMass_kg = 0.70;
        attribute :>> equivalentMass_kg = 2.49;
    }
    part aerogel75 : InsulationAlternative {
        attribute :>> material = "Silica aerogel";
        attribute :>> thickness_mm = 75.0;
        attribute :>> heaterAvg_W = 7.03;
        attribute :>> insulationMass_kg = 1.19;
        attribute :>> equivalentMass_kg = 2.53;
    }
    part mli50 : InsulationAlternative {
        attribute :>> material = "MLI in Mars CO2";
        attribute :>> thickness_mm = 50.0;
        attribute :>> heaterAvg_W = 13.90;
        attribute :>> insulationMass_kg = 1.86;
        attribute :>> equivalentMass_kg = 4.50;
    }

    analysis insulationTrade : TradeStudy {
        doc /* Minimise insulation mass plus the array mass needed to power the
             * heaters. Aerogel at 50-75 mm is within 0.1 kg of the optimum; the
             * design takes 75 mm for extra survival margin (TCS-10). */
        subject alternatives : InsulationAlternative [3] = (aerogel50, aerogel75, mli50);
        objective :>> tradeStudyObjective : MinimizeObjective;
        calc :>> evaluationFunction {
            in part alternative : InsulationAlternative;
            return attribute score : Real = alternative.equivalentMass_kg;
        }
        return part selected : InsulationAlternative;
    }
}
