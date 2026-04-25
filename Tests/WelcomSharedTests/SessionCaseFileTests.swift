import Testing
@testable import WelcomShared

@Test func caseFileTracksClaimEvidenceAndMode() {
    let evidence = SessionEvidence(
        title: "Photo of invoice",
        detail: "Shows the disputed charge amount.",
        kind: .document,
        fileName: "invoice.pdf",
        addedByUserId: "host-1"
    )

    let caseFile = SessionCaseFile(
        claimText: "I was charged twice for the same repair.",
        requestedOutcome: "Refund the duplicate charge.",
        communicationMode: .videoCall,
        evidenceItems: [evidence]
    )

    #expect(caseFile.hasSupportingEvidence)
    #expect(caseFile.communicationMode.displayName == "Video call")
    #expect(caseFile.evidenceItems.first?.documentationLine.contains("invoice.pdf") == true)
}

@Test func sessionKeepsCaseFileWithoutBreakingDefaults() {
    let session = Session(
        title: "Billing Dispute",
        sessionCode: "ABC123",
        caseFile: SessionCaseFile(
            claimText: "Incorrect final balance.",
            communicationMode: .structuredConversation,
            evidenceItems: [
                SessionEvidence(
                    title: "Account notes",
                    detail: "Timeline of prior support conversations.",
                    kind: .text,
                    addedByUserId: "host-1"
                )
            ]
        ),
        partyAId: "host-1",
        partyBId: "guest-1",
    )

    #expect(session.caseFile?.claimText == "Incorrect final balance.")
    #expect(session.caseFile?.evidenceItems.count == 1)
    #expect(session.totalTurns == 4)
}

@Test func sessionSummaryHighlightsEqualTimeFairness() {
    let session = Session(
        title: "Shared Parenting Plan",
        sessionCode: "FAIR12",
        status: .active,
        currentTurn: .partyA,
        currentTurnNumber: 1,
        maxTurns: 3,
        turnDuration: 60,
        partyAId: "host-1",
        partyBId: "guest-1",
        partyAName: "Taylor",
        partyBName: "Jordan"
    )

    let summary = SessionSummaryViewModel(session: session)

    #expect(summary.totalRoundsText == "3 equal rounds each")
    #expect(summary.fairnessLine.contains("Equal time for each participant"))
    #expect(summary.accessibilitySummary.contains("Equal time for each participant"))
}
