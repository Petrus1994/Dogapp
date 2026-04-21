import Foundation

protocol PlanServiceProtocol {
    func generatePlan(for dogProfile: DogProfile) async throws -> Plan
    func generatePlanForNoDog(scenarioType: User.ScenarioType, breed: String?) async throws -> Plan
}

final class MockPlanService: PlanServiceProtocol {
    func generatePlan(for dogProfile: DogProfile) async throws -> Plan {
        try await Task.sleep(nanoseconds: 2_000_000_000)

        switch dogProfile.ageGroup {
        case .under2Months, .twoTo3Months, .threeTo5Months:
            return MockData.puppyPlan
        default:
            return MockData.adultCorrectionPlan
        }
    }

    func generatePlanForNoDog(scenarioType: User.ScenarioType, breed: String?) async throws -> Plan {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return MockData.preparationPlan
    }
}

// MARK: - AI Prompt template (attach to real service)
/*
 System prompt (store in Prompts/plan_generation.txt or server-side):

 You are a professional dog trainer with 15+ years of experience.
 Given the following dog profile, generate a personalized 7-day training plan.
 Return JSON matching the Plan schema.

 Dog profile: {{dogProfile}}
 Current issues: {{issues}}
 Age group: {{ageGroup}}
 Breed: {{breed}}

 Focus on positive reinforcement. Keep tasks realistic and specific.
 Each task should take 10–15 minutes maximum.
*/
