================================================================================
NEXUS AGENT PROTOCOL — REMAINING WORK + LIMITATIONS
Last updated: July 2026
================================================================================


================================================================================
SECTION 1: REMAINING UI PAGES (not yet built)
================================================================================

These pages are in the UI plan but not implemented yet.
The contracts are deployed and working — only the frontend is missing.

────────────────────────────────────────────────────────────────────────────────
UI PHASE C: ZK ESCROW PAGE (/escrow)
────────────────────────────────────────────────────────────────────────────────
What it is:
  Trustless task payment. Client deposits ETH, commits to expected result.
  Agent proves work via ZK proof. Payment releases automatically — no client
  approval needed. The most unique feature of Nexus.

Pages to build:
  - /escrow                     : list all your escrows (as client or agent)
  - /escrow/create              : create new escrow form
  - /escrow/[id]                : single escrow detail + proof submission

Components to build:
  - CreateEscrowForm.tsx        : taskId, agentWallet, deadline, reward fields
  - CommitmentHelper.tsx        : computes keccak256(resultHash, salt) client-side,
                                  shows salt to share with agent
  - ProofSubmitForm.tsx         : paste proof JSON from generate-proof.js, submit
  - EscrowStatusCard.tsx        : OPEN / RELEASED / REFUNDED / DISPUTED badge
  - EscrowList.tsx              : paginated list of escrows

Hooks to build:
  - frontend/lib/hooks/useZKEscrow.ts
    Functions: createEscrow (payable), setCommitment, releaseWithProof,
               refundAfterDeadline, raiseDispute, getEscrow, getTaskEscrow

Contract: ZKEscrow at 0x2EcD5ce3d5140aB7Df3063aAB817AF1336d04416
ABI already in contracts.ts: ZK_ESCROW_ABI ✓

Key UX note:
  - Commitment = keccak256(abi.encodePacked(resultHash, salt))
  - Client computes this in browser, sets on-chain, shares salt with agent
  - Agent generates ZK proof off-chain via scripts/zk/generate-proof.js
  - Agent submits proof on-chain to release payment

────────────────────────────────────────────────────────────────────────────────
UI PHASE D: SUB-TASKS / COMPOSABILITY PAGE (/dashboard/subtasks)
────────────────────────────────────────────────────────────────────────────────
What it is:
  Agents hiring agents. Parent agent creates sub-tasks, assigns sub-agents,
  approves work. Revenue split is trustless and automatic.

Pages to build:
  - /dashboard/subtasks         : list all sub-tasks you're involved in
  - /dashboard/subtasks/create  : create sub-task form

Components to build:
  - SubTaskCard.tsx             : sub-task with status OPEN/ASSIGNED/SUBMITTED/COMPLETED
  - CreateSubTaskForm.tsx       : parentTaskId, metadataURI, deadline, splitBps, reward
  - AssignSubAgentPicker.tsx    : search discovery, pick sub-agent
  - SubTaskStatusTracker.tsx    : step-by-step progress indicator
  - RelationshipCard.tsx        : shows collab history between two agents
  - ApproveWorkButton.tsx       : approve work and trigger auto-payment

Hooks to build:
  - frontend/lib/hooks/useAgentComposability.ts
    Functions: createSubTask (payable), assignSubAgent, submitSubWork,
               approveSubWork, cancelSubTask, getSubTask, getAgentRelationship,
               getParentSubTasks, getSubAgentTasks

Contract: AgentComposability at 0x4628ba31A9264e7eA204b62849e17AF5E10b1f55
ABI already in contracts.ts: AGENT_COMPOSABILITY_ABI ✓



────────────────────────────────────────────────────────────────────────────────
UI PHASE F: COMMUNITY GRANTS PAGE (/grants)
────────────────────────────────────────────────────────────────────────────────
 
Pages to build:
  - /grants                     : active + past grants list
  - /grants/[id]                : grant detail + vote panel
 
Components:
  - GrantCard.tsx               : title, type badge, amount, voting progress
  - ProposeGrantForm.tsx        : title, description, recipient, amount, type selector
  - GrantVotePanel.tsx          : FOR / AGAINST with reputation weight shown
  - GrantStatusTimeline.tsx     : VOTING → APPROVED → TIMELOCK → EXECUTED
 
Hooks to build:
  - frontend/lib/hooks/useCommunityGrants.ts



────────────────────────────────────────────────────────────────────────────────
UI PHASE G: AGENT DAO PAGE (/dao)
────────────────────────────────────────────────────────────────────────────────
 
Pages to build:
  - /dao                        : list DAOs you're part of + create DAO button
  - /dao/[id]                   : DAO detail, members, proposals, earnings
 
Components:
  - DAOCard.tsx                 : name, member count, total earned, success rate
  - CreateDAOForm.tsx           : name, member agent IDs, split percentages (must sum 100%)
  - RevenueSplitPie.tsx         : pie chart showing split percentages
  - DAOProposalCard.tsx         : task proposal + vote buttons
  - MemberList.tsx              : member agents with their split %
 
Hooks to build:
  - frontend/lib/hooks/useAgentDAO.ts
 
────────────────────────────────────────────────────────────────────────────────
UI PHASE H: RESULT STORAGE PAGE (/results)
────────────────────────────────────────────────────────────────────────────────

Pages to build:
  - /results                    : all anchored results for your agent
  - /results/anchor             : anchor a new Arweave result

Components:
  - AnchorResultForm.tsx        : taskId, Arweave TX ID (43 chars), content hash, type
  - ResultCard.tsx              : shows arweaveTxId with link to arweave.net/[txId]
  - VerifyResultButton.tsx      : fetch from Arweave, hash, call verifyResult()
  - VerificationBadge.tsx       : ANCHORED (yellow) vs VERIFIED (green)

────────────────────────────────────────────────────────────────────────────────
UI PHASE I: WORKFLOW COORDINATOR (/workflows)
────────────────────────────────────────────────────────────────────────────────

Pages to build:
  - /workflows                  : list your active workflows
  - /workflows/create           : pipeline vs parallel builder
  - /workflows/[id]             : stage-by-stage progress, submit results

Components:
  - PipelineBuilder.tsx         : add stages with agent + budget + deadline per stage
  - ParallelWorkflowBuilder.tsx : select parallel agents + aggregator
  - WorkflowCard.tsx            : status ACTIVE/COMPLETED/FAILED/CANCELLED
  - StageTracker.tsx            : visual step progress (PENDING→ACTIVE→COMPLETED)
  - SubmitStageResultForm.tsx   : paste result URI, submit on-chain

────────────────────────────────────────────────────────────────────────────────
UI PHASE J: PROTOCOL GUARD ADMIN (/admin/guard)
────────────────────────────────────────────────────────────────────────────────

Visibility: Only show this page when connected wallet == protocolOwner

Components:
  - ContractStatusGrid.tsx      : all 22 contracts, pause status, expiry
  - PauseContractForm.tsx       : target address, reason, duration
  - InvariantMonitorPanel.tsx   : registered invariants, last check, violation count
  - RateLimiterConfig.tsx       : current window, current outflow, threshold

────────────────────────────────────────────────────────────────────────────────
EXISTING PAGES THAT NEED LIVE DATA (currently using mock data)
────────────────────────────────────────────────────────────────────────────────
1. /agents (AgentGrid)
   Currently: MOCK_AGENTS array
   Fix: Read from AgentDiscovery.getIndexedAgents() + AgentRegistry.getAgent()
   Hook: useAgentDiscovery already in contracts.ts

2. /tasks (TaskGrid)
   Currently: MOCK_TASKS array
   Fix: Read TaskPosted events from The Graph or direct RPC getLogs
   Subgraph endpoint: api.studio.thegraph.com/query/1755484/nexus-agent-protocol/v0.1.0

3. /dashboard (stats panels)
   Currently: MOCK_STATS object
   Fix: Read totalAgents, totalTasks from contracts directly
   Some panels (ActiveTasksPanel, EarningsPanel) need agent-specific data

4. Home page StatsBar
   Currently: MOCK_STATS
   Fix: Read totalAgents + totalTasks from chain

5. ActivityTicker
   Currently: TICKER_ITEMS hardcoded array
   Fix: Subscribe to contract events (TaskCompleted, AgentRegistered etc.)
        or poll The Graph for recent events


================================================================================
SECTION 2: CONTRACTS NOT YET DEPLOYED TO SEPOLIA
================================================================================

CCIP_ROUTER=0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59
ZK_VERIFIER_ADDR=0xA292dA54BF85BD6692B1082ceB88a1F6d671EFe8
AGENT_REGISTRY_ADDR=0x68F76277A7a8991CE7ac7182AAA10a356dAaB48F
AVS_METADATA_URI=https://raw.githubusercontent.com/adityachotaliya9299-jpg/nexus-agent-protocol/main/avs-metadata.json
SERVICE_MANAGER_ADDR=0x2E1eF805b574094AFDF84f86b4B9bf07697F3080
REPUTATION_ORACLE_ADDR=0x7deC5525AC26Bcf134c5e8cD7485c16CBC00EeDA
TASK_MARKETPLACE_ADDR=0x16B3cD374B3596635A76D874c1A3138e7236C76e
AGENT_STAKING_ADDR=0x30852aE83c52a6140A64F63d62d5AeA284d3e723
SKILL_NFT_ADDR=0x8f45Bd7d2FFa5fB1c17612D4CcE89c1d9d4746A4
IDENTITY_NFT_ADDR=0xB09a7a641dBF6c8cB0430EDA307e48eAdFa9EA50
COMPOSABILITY_ADDR=0x4628ba31A9264e7eA204b62849e17AF5E10b1f55
ZK_ESCROW_ADDR=0x2EcD5ce3d5140aB7Df3063aAB817AF1336d04416
CONTEXTUAL_REP_ADDR=0xAFE6c16FA37bB0BD9E7A24901705C7Fe725A910A
DISCOVERY_ADDR=0x08787B020D4Ded4Beb9Ff116e041047491A7F126
RESULT_STORAGE_ADDR=0xb38c9dE16a775303b784367cd75304E52351518b
AGENT_DAO_ADDR=0x02E52e89dD06A743044C9A4207b001C1c074D8EC
COMMUNITY_GRANTS_ADDR=0xD59eCf4296095fBC32576CF1e86e8b835aeac3a4
PROTOCOL_GUARD_ADDR=0x02bc33be83eC39a399b00D40721898e1b396cB24
L1_BRIDGE_ADDR=0xbF0c07609a8693D3E6B0a25F784fCD2a8333c5Ae
L2_BRIDGE_ADDR=0x9CB0593354408A7c4943e553dFCbb4670379b7A0
COORDINATOR_ADDR=0xa14b2dd25279e5bCd8aF219e336b3A48b47124B1

here is the address of each if i have not added any of this in to frontend/lib/contracts.ts(CONTRACTS object) and sdk/src/utils/constants.ts (NEXUS_SEPOLIA_CONTRACTS) and docs/README.md (contract table) so add that




