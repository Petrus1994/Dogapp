import Foundation

struct ActivityBalanceService {

    struct BalanceReport {
        var physicalMinutes: Int    // walk + play combined
        var mentalMinutes: Int      // training
        var physicalTarget: Int
        var mentalTarget: Int
        var physicalFraction: Double
        var mentalFraction: Double
        var isPhysicalDeficit: Bool
        var isMentalDeficit: Bool
        var isOverloaded: Bool      // training > 2× recommended max

        var overallBalance: BalanceState

        enum BalanceState {
            case balanced       // both within target
            case physicalLow    // needs more physical activity
            case mentalLow      // needs more mental stimulation
            case bothLow        // both lacking
            case overtrained    // training sessions too long
        }

        var coachingMessage: String? {
            switch overallBalance {
            case .balanced:
                return nil
            case .physicalLow:
                return "Your dog has plenty of mental exercise but needs more physical activity. Physical exercise reduces excess energy and makes training far more effective."
            case .mentalLow:
                return "Physical activity looks good! Adding even one short training session would help — mental exercise tires dogs out faster than physical activity."
            case .bothLow:
                return "Your dog is under-stimulated today. Start with a short walk to release energy, then follow with 5 minutes of focused training."
            case .overtrained:
                return "Training sessions today exceeded the safe limit. Overstimulation causes frustration and makes the dog associate training with stress. Keep sessions short and always end on a success."
            }
        }

        var physicalLabel: String {
            "\(physicalMinutes) / \(physicalTarget) min"
        }

        var mentalLabel: String {
            "\(mentalMinutes) / \(mentalTarget) min"
        }
    }

    // MARK: - Analysis

    static func analyze(
        activities: [DailyActivity],
        norms: ActivityNorms?
    ) -> BalanceReport {
        let walkMin  = activities.filter { $0.type == .walking && $0.completed }
            .reduce(0) { $0 + $1.durationMinutes }
        let playMin  = activities.filter { $0.type == .playing && $0.completed }
            .reduce(0) { $0 + $1.durationMinutes }
        let trainMin = activities.filter { $0.type == .training && $0.completed }
            .reduce(0) { $0 + $1.durationMinutes }

        let physicalMin = walkMin + playMin
        let mentalMin   = trainMin

        let physicalTarget = (norms?.walkMinPerDay ?? 30) + (norms?.playMinPerDay ?? 20)
        let mentalTarget   = (norms?.trainingMinPerSession ?? 10) * (norms?.trainingSessionsPerDay ?? 2)
        let mentalMax      = mentalTarget * 2

        let physicalFraction = physicalTarget > 0 ? min(Double(physicalMin) / Double(physicalTarget), 1.0) : 1.0
        let mentalFraction   = mentalTarget   > 0 ? min(Double(mentalMin)   / Double(mentalTarget),   1.0) : 1.0

        let isPhysicalDeficit = physicalFraction < 0.5
        let isMentalDeficit   = mentalFraction   < 0.5
        let isOverloaded      = mentalMin > mentalMax

        let state: BalanceReport.BalanceState
        if isOverloaded {
            state = .overtrained
        } else if isPhysicalDeficit && isMentalDeficit {
            state = .bothLow
        } else if isPhysicalDeficit {
            state = .physicalLow
        } else if isMentalDeficit {
            state = .mentalLow
        } else {
            state = .balanced
        }

        return BalanceReport(
            physicalMinutes: physicalMin,
            mentalMinutes: mentalMin,
            physicalTarget: physicalTarget,
            mentalTarget: mentalTarget,
            physicalFraction: physicalFraction,
            mentalFraction: mentalFraction,
            isPhysicalDeficit: isPhysicalDeficit,
            isMentalDeficit: isMentalDeficit,
            isOverloaded: isOverloaded,
            overallBalance: state
        )
    }
}
