# Parallel Task Execution Guide

This document identifies which tasks can be executed in parallel to maximize development efficiency.

## Parallel Execution Groups

### 🟢 Group 1: Foundation (Can Start Immediately)

**Timeline**: Day 1-2

| Task ID | Task Name | Team Member | Status |
|---------|-----------|-------------|--------|
| 1.2 | Clock & Reset Infrastructure | Developer A | ⬜ Not Started |
| 1.3 | Button Debouncer Module | Developer B | ⬜ Not Started |
| 1.4 | VGA Sync Module | Developer C | ⬜ Not Started |

**No Dependencies** - All can start simultaneously after Task 1.1 (Project Setup)

---

### 🟢 Group 2: Memory & Assets (Can Start After Group 1)

**Timeline**: Day 2-4

| Task ID | Task Name | Team Member | Status |
|---------|-----------|-------------|--------|
| 2.1 | SRAM Controller Module | Developer A | ⬜ Not Started |
| 2.2 | Asset Prep - Background | Artist/Developer D | ⬜ Not Started |
| 2.3 | Asset Prep - Drinks | Artist/Developer D | ⬜ Not Started |
| 2.4 | Asset Prep - Coins & UI | Artist/Developer D | ⬜ Not Started |

**Dependencies**:
- All need Phase 1 concepts understood
- Asset tasks (2.2-2.4) can be done by non-Verilog team members
- Assets can use placeholder colors initially for testing

---

### 🟢 Group 3: Core Controllers (Can Start After FSM - Task 3.1)

**Timeline**: Day 5-8

| Task ID | Task Name | Team Member | Status |
|---------|-----------|-------------|--------|
| 3.2 | Selection Controller | Developer B | ⬜ Not Started |
| 3.3 | Payment Controller | Developer A | ⬜ Not Started |
| 3.4 | Coin Inventory Manager | Developer C | ⬜ Not Started |

**Dependencies**:
- Requires Task 3.1 (Main FSM) to define interfaces
- All three can proceed in parallel once FSM interface is defined
- Can use mock inputs for individual testing

---

### 🟢 Group 4A: Rendering Foundation (After Display Hub - Task 4.1)

**Timeline**: Day 9-11

| Task ID | Task Name | Team Member | Status |
|---------|-----------|-------------|--------|
| 4.2 | Background Renderer | Developer C | ⬜ Not Started |
| 4.3 | Sprite Renderer | Developer A | ⬜ Not Started |

**Dependencies**:
- Requires Task 4.1 (Display Controller Hub)
- Both can work in parallel
- Can test independently with test patterns

---

### 🟢 Group 4B: Screen Renderers (After Group 4A + Task 4.4)

**Timeline**: Day 11-13

| Task ID | Task Name | Team Member | Status |
|---------|-----------|-------------|--------|
| 4.6 | Payment Screen Renderer | Developer B | ⬜ Not Started |
| 4.7 | Dispensing & Message Renderer | Developer D | ⬜ Not Started |

**Dependencies**:
- Requires Tasks 4.3 (Sprite) and 4.4 (Text) completed
- Both can work in parallel
- Task 4.5 (Selection Screen) is on critical path, not parallel

---

## Parallelization Strategy

### Maximum Parallelization Scenario (4 Developers)

```
Developer A (Verilog Expert - Complex Logic):
  Day 1-2:   Task 1.2 (Clock Infrastructure)
  Day 3-5:   Task 2.1 (SRAM Controller)
  Day 6-8:   Task 3.3 (Payment Controller) ⭐ Complex
  Day 9-11:  Task 4.3 (Sprite Renderer)
  Day 12-14: Task 5.1 (Integration Lead)

Developer B (Verilog - FSM & Control):
  Day 1-2:   Task 1.3 (Button Debouncer)
  Day 3-5:   Task 3.1 (Main FSM) ⭐ Critical Path
  Day 6-8:   Task 3.2 (Selection Controller)
  Day 9-11:  Task 4.4 (Text Renderer)
  Day 12-14: Task 4.6 (Payment Screen)

Developer C (Verilog - Display & Timing):
  Day 1-2:   Task 1.4 (VGA Sync)
  Day 3-5:   Task 4.1 (Display Controller Hub) ⭐ Critical Path
  Day 6-8:   Task 3.4 (Coin Manager)
  Day 9-11:  Task 4.2 (Background Renderer)
  Day 12-14: Task 4.5 (Selection Screen)

Developer D (Assets + Verilog Support):
  Day 1-4:   Tasks 2.2, 2.3, 2.4 (All Asset Prep) 🎨
  Day 5:     Task 2.5 (Memory Init Helper)
  Day 6-8:   Task 3.5 (Drink Inventory)
  Day 9-11:  Task 4.7 (Message Renderer)
  Day 12-14: Task 5.2 (Testbench)
```

### Minimum Team Scenario (2 Developers)

```
Developer A (Lead):
  Week 1: Tasks 1.1, 1.2, 1.3, 2.1
  Week 2: Tasks 3.1, 3.2, 3.3
  Week 3: Tasks 4.1, 4.3, 4.4, 4.5
  Week 4: Tasks 5.1, 5.2, 5.3, 5.4

Developer B (Support):
  Week 1: Tasks 1.4, 2.2, 2.3, 2.4, 2.5
  Week 2: Tasks 3.4, 3.5
  Week 3: Tasks 4.2, 4.6, 4.7
  Week 4: Support A with integration and testing
```

### Solo Developer Scenario

Follow the phase order sequentially:
- Phase 1: 2 days
- Phase 2: 3 days (use simple colored rectangles as temporary assets)
- Phase 3: 4 days
- Phase 4: 5 days
- Phase 5: 3 days
**Total**: ~17 days

---

## Critical Path (Cannot be Parallelized)

These tasks MUST be completed sequentially:

```
1.1 Project Setup
  ↓
3.1 Main FSM Controller ⭐ BLOCKING
  ↓
4.1 Display Controller Hub ⭐ BLOCKING
  ↓
4.4 Text & Number Renderer
  ↓
4.5 Selection Screen Renderer ⭐ BLOCKING
  ↓
5.1 Top Module Integration ⭐ BLOCKING
  ↓
5.2 Simulation Testbench
  ↓
5.3 Synthesis & Timing
  ↓
5.4 Hardware Testing
```

**Critical Path Duration**: ~8-10 days minimum

---

## Dependency Graph

```
           ┌─────┐
           │ 1.1 │ Project Setup
           └──┬──┘
              │
     ┌────────┼────────┐
     │        │        │
  ┌──▼──┐  ┌─▼──┐  ┌──▼──┐
  │ 1.2 │  │1.3 │  │ 1.4 │  [PARALLEL GROUP 1]
  └──┬──┘  └─┬──┘  └──┬──┘
     │        │        │
  ┌──▼──┐  ┌─▼──┐    │
  │ 2.1 │  │3.1 │◄───┘
  └──┬──┘  └─┬──┘ (FSM - CRITICAL)
     │        │
     │     ┌──▼────────┬────────┐
     │     │           │        │
     │  ┌──▼──┐     ┌──▼──┐  ┌─▼──┐
     │  │ 3.2 │     │ 3.3 │  │3.4 │  [PARALLEL GROUP 3]
     │  └──┬──┘     └──┬──┘  └─┬──┘
     │     │           │        │
     │     └────┬──────┴────────┘
     │          │
  ┌──▼──────────▼──┐
  │      4.1       │  Display Hub (CRITICAL)
  └───┬───────┬───┘
      │       │
   ┌──▼──┐ ┌─▼──┐
   │ 4.2 │ │4.3 │  [PARALLEL GROUP 4A]
   └──┬──┘ └─┬──┘
      │      │
      │   ┌──▼──┐
      │   │ 4.4 │  Text Renderer
      │   └──┬──┘
      │      │
      │   ┌──▼──┐
      │   │ 4.5 │  Selection Screen (CRITICAL)
      │   └──┬──┘
      │      │
      │   ┌──▼────┬────┐
      │   │       │    │
      │ ┌─▼──┐ ┌─▼──┐ │
      │ │4.6 │ │4.7 │ │  [PARALLEL GROUP 4B]
      │ └─┬──┘ └─┬──┘ │
      │   │      │    │
      └───┴──┬───┴────┘
             │
          ┌──▼──┐
          │ 5.1 │  Integration (CRITICAL)
          └──┬──┘
             │
          ┌──▼──┐
          │ 5.2 │  Testbench
          └──┬──┘
             │
          ┌──▼──┐
          │ 5.3 │  Synthesis
          └──┬──┘
             │
          ┌──▼──┐
          │ 5.4 │  Hardware Test
          └─────┘

Assets (2.2-2.5) can happen anytime before Phase 4
```

---

## Coordination Points (Synchronization Required)

### Sync Point 1: After Phase 1
**Wait for**: All of Group 1 (1.2, 1.3, 1.4) complete
**Then**: Can start Phase 2 and 3.1

### Sync Point 2: After FSM (Task 3.1)
**Wait for**: Task 3.1 complete
**Then**: Can start Group 3 (3.2, 3.3, 3.4)

### Sync Point 3: After Display Hub (Task 4.1)
**Wait for**: Task 4.1 complete
**Then**: Can start Group 4A (4.2, 4.3)

### Sync Point 4: After Sprite & Text (Tasks 4.3, 4.4)
**Wait for**: Both 4.3 and 4.4 complete
**Then**: Can start Group 4B (4.6, 4.7) in parallel

### Sync Point 5: Before Integration (Task 5.1)
**Wait for**: ALL Phase 1-4 tasks complete
**Then**: Begin integration

---

## Tips for Parallel Development

1. **Define Interfaces Early**:
   - Task 3.1 (FSM) must define controller interfaces before Group 3 starts
   - Task 4.1 (Display Hub) must define renderer interfaces before Group 4 starts

2. **Use Mock Data**:
   - Controllers can use hardcoded test data before assets are ready
   - Renderers can use simple colored blocks before sprites are ready

3. **Version Control**:
   - Use separate branches for parallel tasks
   - Regular merges to catch integration issues early

4. **Communication**:
   - Daily standups to coordinate interface changes
   - Shared documentation for register maps and signals

5. **Testing**:
   - Each module should have its own testbench
   - Don't wait for full integration to start testing

6. **Asset Pipeline**:
   - Assets (Group 2) can start immediately with just size specifications
   - Use placeholder assets (colored rectangles) for early testing
   - Replace with final assets later

---

## Progress Tracking Template

| Phase | Total Tasks | Completed | In Progress | Not Started | % Done |
|-------|-------------|-----------|-------------|-------------|--------|
| 1     | 4           | 0         | 0           | 4           | 0%     |
| 2     | 5           | 0         | 0           | 5           | 0%     |
| 3     | 5           | 0         | 0           | 5           | 0%     |
| 4     | 7           | 0         | 0           | 7           | 0%     |
| 5     | 6           | 0         | 0           | 6           | 0%     |
| **Total** | **27** | **0** | **0** | **27** | **0%** |

---

## Quick Start Guide

### For Team Lead:
1. Assign developers to parallel groups
2. Ensure Task 1.1 is completed first
3. Kick off Group 1 tasks simultaneously
4. Monitor critical path tasks (3.1, 4.1, 5.1)
5. Coordinate sync points

### For Individual Developers:
1. Check your assigned tasks in the parallelization scenario
2. Understand your task dependencies
3. Create your module testbench first (TDD approach)
4. Communicate interface changes immediately
5. Mark tasks complete when tested individually

### For Asset Creators:
1. Start with Task 2.2 (background is simplest)
2. Use the specified image sizes and color format
3. Test early with placeholder patterns
4. Can work completely independently from Verilog developers
5. Coordinate with Task 2.5 for memory file generation

---

## Risk Mitigation

**Risk**: Critical path tasks (3.1, 4.1) delayed
**Mitigation**: Assign most experienced developers; start early; have backup support

**Risk**: Interface mismatches between parallel modules
**Mitigation**: Define interfaces in specification first; review before coding

**Risk**: Integration failures at Sync Points
**Mitigation**: Test modules individually; do incremental integration; maintain good documentation

**Risk**: Asset delays blocking renderer testing
**Mitigation**: Use placeholder assets (simple patterns); assets are not critical path

---

**Last Updated**: 2025-11-26
**Status**: Ready for development kickoff
