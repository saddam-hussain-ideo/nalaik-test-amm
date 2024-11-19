# SingleSidedAMM - Architecture Presentation

## Overview

The `SingleSidedAMM` contract is a simplified Automated Market Maker (AMM) that allows users to swap tokens in a single-sided manner. Instead of swapping the entire amount at once, it introduces a streaming mechanism where the total swap amount is divided into multiple chunks (streams) processed over time. This approach aims to reduce market impact and provide a smoother trading experience.

## Table of Contents

- [Swap Flow and Stream Processing Strategy](#swap-flow-and-stream-processing-strategy)
    - [Swap Flow](#swap-flow)
    - [Stream Processing Strategy](#stream-processing-strategy)
- [Optimizations for Gas Efficiency and Data Management](#optimizations-for-gas-efficiency-and-data-management)
    - [Gas Efficiency](#gas-efficiency)
    - [Data Management](#data-management)

## Swap Flow and Stream Processing Strategy

### Swap Flow

1. **User Initiation**:
    - Users start a swap by calling the `enterSwap` function.
    - Parameters:
        - `amount`: Total amount to swap.
        - `isTokenA`: `true` if swapping Token A for B; `false` for Token B for A.

2. **Balance and Reserve Checks**:
    - **Balance Verification**: Ensures the user has enough balance of the token they're swapping.
    - **Liquidity Verification**: Checks that the opposite reserve has sufficient liquidity.

3. **Updating Balances and Reserves**:
    - Decreases the user's token balance by the swap amount.
    - Increases the corresponding reserve, adding liquidity to the pool.

4. **Stream Creation**:
    - Creates a `Stream` struct containing:
        - `totalAmount`: The total swap amount.
        - `amountSwapped`: Amount already swapped (initially zero).
        - `streamCount`: Number of chunks the amount is divided into.
        - `nextChunkIndex`: Index of the next chunk to process.
        - `isTokenA`: Swap direction indicator.
    - **Stream Count Calculation**:
        - Calculated as `(amount * scalingFactor) / oppositeReserve`.
        - Ensures at least one stream is created to prevent division by zero.

5. **Event Emission**:
    - Emits a `SwapEntered` event with details of the swap initiation.

### Stream Processing Strategy

1. **Processing Streams**:
    - Users or any entity can call `processStream` to process the next chunk of a user's stream.
    - Internally calls `_processStream` for logic execution.

2. **Chunk Processing**:
    - **Chunk Amount**:
        - Calculated as `totalAmount / streamCount`.
        - Adjusted on the last chunk to ensure full amount is processed.
    - **AMM Mechanics**:
        - Utilizes the constant product formula `k = reserveA * reserveB`.
        - For Token A to B swaps:
            - Increases `reserveA` by `chunkAmount`.
            - Calculates new `reserveB = k / reserveA`.
            - Determines `amountOut = reserveB - newReserveB`.
            - Updates `reserveB` and credits `amountOut` to the user's `balanceB`.
        - Token B to A swaps follow a similar logic with reserves swapped.

3. **Updating Stream State**:
    - Increments `amountSwapped` by `chunkAmount`.
    - Increments `nextChunkIndex`.
    - Emits a `StreamProcessed` event.

4. **Completion and Cleanup**:
    - Deletes the user's stream from the `streams` mapping when all chunks are processed to free storage space.

## Optimizations for Gas Efficiency and Data Management

### Gas Efficiency

- **State Variable Updates**:
    - Minimizes writes to storage by updating only when necessary.
    - Ensures state changes occur before emitting events to save gas.

- **Efficient Calculations**:
    - Stores intermediate results to avoid redundant calculations.
    - Carefully uses integer division to prevent precision loss.

- **Scaling Factor Adjustment**:
    - The `scalingFactor` (`1000`) controls stream granularity.
    - Balances the number of chunks and gas cost per user.

- **Function Modularity**:
    - Uses internal functions like `_processStream` for reuse and optimization.
