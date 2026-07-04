// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IProtocolGuard} from "./IProtocolGuard.sol";

/// @title ProtocolGuard
/// @author Aditya Chotaliya [adityachotaliya.xyz]
/// @notice On-chain security layer for Nexus Agent Protocol.
///
/// @dev Combines four security primitives into one contract:
///
///   1. CIRCUIT BREAKER - pause any contract up to 7 days
///   2. INVARIANT MONITOR - register + check on-chain invariants
///   3. GUARDIAN SYSTEM - multi-guardian pause with 2/3 unpause quorum
///   4. RATE LIMITER - auto-pause on anomalous ETH outflow
///
///   Integration pattern (in every Nexus contract):
///     modifier whenNotPaused() {
///         if (IProtocolGuard(GUARD_ADDR).isPaused(address(this))) revert ProtocolIsPaused();
///         _;
///     }
contract ProtocolGuard is IProtocolGuard {

    // ── Constants ────────────────────────────────────────────────

    uint256 public constant MAX_PAUSE_DURATION = 7 days;
    uint256 public constant GUARDIAN_QUORUM    = 2; // out of 3 to unpause

    // ── Storage ──────────────────────────────────────────────────

    address public immutable protocolOwner;

    bool    public globalPause;

    mapping(address => ContractStatus) private _contractStatus;
    mapping(bytes32 => Invariant)      private _invariants;
    mapping(address => bool)           public override isGuardian;
    mapping(address => mapping(address => bool)) private _guardianUnpauseVotes;

    bytes32[] private _invariantIds;
    address[] private _guardians;

    RateLimit private _rateLimit;

    uint256 private _nonce;

    // ── Modifiers ────────────────────────────────────────────────

    modifier onlyOwner() {
        if (msg.sender != protocolOwner) revert NotAuthorized();
        _;
    }

    modifier onlyOwnerOrGuardian() {
        if (msg.sender != protocolOwner && !isGuardian[msg.sender]) revert NotAuthorized();
        _;
    }

    // ── Constructor ───────────────────────────────────────────────

    constructor(address _protocolOwner) {
        if (_protocolOwner == address(0)) revert ZeroAddress();
        protocolOwner = _protocolOwner;

        // Default rate limit: 10 ETH per hour
        _rateLimit = RateLimit({
            windowSeconds:  3600,
            maxOutflowWei:  10 ether,
            currentOutflow: 0,
            windowStartedAt: block.timestamp
        });
    }

    // ── Circuit Breaker ───────────────────────────────────────────

    function pause(address target, string calldata reason, uint256 duration)
        external override onlyOwnerOrGuardian
    {
        if (target == address(0)) revert ZeroAddress();
        if (_contractStatus[target].isPaused) revert AlreadyPaused(target);
        if (duration > MAX_PAUSE_DURATION) revert PauseTooLong(duration, MAX_PAUSE_DURATION);

        uint256 expiresAt = block.timestamp + (duration == 0 ? MAX_PAUSE_DURATION : duration);

        _contractStatus[target] = ContractStatus({
            target:         target,
            isPaused:       true,
            pausedAt:       block.timestamp,
            pauseExpiresAt: expiresAt,
            pausedBy:       msg.sender,
            pauseReason:    reason,
            totalPauses:    _contractStatus[target].totalPauses + 1
        });

        emit ContractPaused(target, msg.sender, reason, expiresAt);
    }

    function unpause(address target) external override onlyOwnerOrGuardian {
        ContractStatus storage s = _contractStatus[target];
        if (!s.isPaused) revert NotPaused(target);

        // If not owner, need guardian quorum
        if (msg.sender != protocolOwner) {
            _guardianUnpauseVotes[target][msg.sender] = true;
            uint256 votes = _countUnpauseVotes(target);
            if (votes < GUARDIAN_QUORUM) return; // Not enough votes yet
            _clearUnpauseVotes(target);
        }

        s.isPaused       = false;
        s.pauseExpiresAt = 0;
        emit ContractUnpaused(target, msg.sender);
    }

    function pauseAll(string calldata reason) external override onlyOwnerOrGuardian {
        globalPause = true;
        emit ProtocolPaused(msg.sender, reason);
    }

    function unpauseAll() external override onlyOwner {
        globalPause = false;
        emit ProtocolUnpaused(msg.sender);
    }

    function isPaused(address target) external view override returns (bool) {
        if (globalPause) return true;
        ContractStatus storage s = _contractStatus[target];
        if (!s.isPaused) return false;
        // Auto-expire check
        if (block.timestamp > s.pauseExpiresAt) return false;
        return true;
    }

    function getContractStatus(address target)
        external view override returns (ContractStatus memory)
    {
        return _contractStatus[target];
    }

    // ── Invariant Monitor ─────────────────────────────────────────

    function registerInvariant(
        string calldata description,
        address target,
        bytes4 selector,
        bool autoPauseOnFail
    ) external override onlyOwner returns (bytes32 invariantId) {
        if (target == address(0)) revert ZeroAddress();

        invariantId = keccak256(abi.encodePacked("inv", target, selector, _nonce++));

        _invariants[invariantId] = Invariant({
            invariantId:      invariantId,
            description:      description,
            target:           target,
            selector:         selector,
            autoPauseOnFail:  autoPauseOnFail,
            isActive:         true,
            lastCheckedAt:    0,
            violationCount:   0
        });

        _invariantIds.push(invariantId);
        emit InvariantRegistered(invariantId, target, description);
    }

    function checkInvariant(bytes32 invariantId) external override returns (bool passed) {
        Invariant storage inv = _invariants[invariantId];
        if (inv.invariantId == bytes32(0)) revert InvariantNotFound(invariantId);
        if (!inv.isActive) return true;

        inv.lastCheckedAt = block.timestamp;

        // Call the invariant check function on the target contract
        (bool success, bytes memory data) = inv.target.staticcall(
            abi.encodePacked(inv.selector)
        );

        // Passed if: call succeeded AND returned true
        passed = success && data.length >= 32 && abi.decode(data, (bool));

        if (!passed) {
            inv.violationCount++;
            emit InvariantViolated(invariantId, inv.target, block.timestamp);

            if (inv.autoPauseOnFail && !_contractStatus[inv.target].isPaused) {
                _contractStatus[inv.target] = ContractStatus({
                    target:         inv.target,
                    isPaused:       true,
                    pausedAt:       block.timestamp,
                    pauseExpiresAt: block.timestamp + 1 hours, // short auto-pause
                    pausedBy:       address(this),
                    pauseReason:    "Invariant violation auto-pause",
                    totalPauses:    _contractStatus[inv.target].totalPauses + 1
                });
                emit ContractPaused(inv.target, address(this), "invariant violation", block.timestamp + 1 hours);
            }
        } else {
            emit InvariantCheckPassed(invariantId);
        }
    }

    function checkAllInvariants() external override returns (uint256 passed, uint256 failed) {
        for (uint256 i = 0; i < _invariantIds.length; i++) {
            bytes32 id = _invariantIds[i];
            if (!_invariants[id].isActive) continue;

            Invariant storage inv = _invariants[id];
            inv.lastCheckedAt = block.timestamp;

            (bool success, bytes memory data) = inv.target.staticcall(
                abi.encodePacked(inv.selector)
            );

            bool ok = success && data.length >= 32 && abi.decode(data, (bool));
            if (ok) {
                passed++;
                emit InvariantCheckPassed(id);
            } else {
                failed++;
                inv.violationCount++;
                emit InvariantViolated(id, inv.target, block.timestamp);
            }
        }
    }

    function getInvariant(bytes32 invariantId)
        external view override returns (Invariant memory)
    {
        if (_invariants[invariantId].invariantId == bytes32(0)) revert InvariantNotFound(invariantId);
        return _invariants[invariantId];
    }

    function totalInvariants() external view override returns (uint256) {
        return _invariantIds.length;
    }

    // ── Guardian System ───────────────────────────────────────────

    function addGuardian(address guardian) external override onlyOwner {
        if (guardian == address(0)) revert ZeroAddress();
        if (isGuardian[guardian]) return;
        isGuardian[guardian] = true;
        _guardians.push(guardian);
        emit GuardianAdded(guardian);
    }

    function removeGuardian(address guardian) external override onlyOwner {
        isGuardian[guardian] = false;
        for (uint256 i = 0; i < _guardians.length; i++) {
            if (_guardians[i] == guardian) {
                _guardians[i] = _guardians[_guardians.length - 1];
                _guardians.pop();
                break;
            }
        }
        emit GuardianRemoved(guardian);
    }

    function guardianCount() external view override returns (uint256) {
        return _guardians.length;
    }

    // ── Rate Limiter ──────────────────────────────────────────────

    function recordOutflow(address target, uint256 amount) external override {
        // Reset window if expired
        if (block.timestamp >= _rateLimit.windowStartedAt + _rateLimit.windowSeconds) {
            _rateLimit.currentOutflow  = 0;
            _rateLimit.windowStartedAt = block.timestamp;
        }

        _rateLimit.currentOutflow += amount;

        if (_rateLimit.currentOutflow > _rateLimit.maxOutflowWei) {
            emit RateLimitTriggered(target, _rateLimit.currentOutflow, _rateLimit.maxOutflowWei);

            // Auto-pause the target contract
            if (!_contractStatus[target].isPaused) {
                _contractStatus[target] = ContractStatus({
                    target:         target,
                    isPaused:       true,
                    pausedAt:       block.timestamp,
                    pauseExpiresAt: block.timestamp + 2 hours,
                    pausedBy:       address(this),
                    pauseReason:    "Rate limit exceeded - auto-pause",
                    totalPauses:    _contractStatus[target].totalPauses + 1
                });
                emit ContractPaused(target, address(this), "rate limit", block.timestamp + 2 hours);
            }
        }
    }

    function getRateLimit() external view override returns (RateLimit memory) {
        return _rateLimit;
    }

    function setRateLimit(uint256 windowSeconds, uint256 maxOutflowWei) external override onlyOwner {
        _rateLimit.windowSeconds = windowSeconds;
        _rateLimit.maxOutflowWei = maxOutflowWei;
    }

    // ── Internal ─────────────────────────────────────────────────

    function _countUnpauseVotes(address target) internal view returns (uint256 count) {
        for (uint256 i = 0; i < _guardians.length; i++) {
            if (_guardianUnpauseVotes[target][_guardians[i]]) count++;
        }
    }

    function _clearUnpauseVotes(address target) internal {
        for (uint256 i = 0; i < _guardians.length; i++) {
            _guardianUnpauseVotes[target][_guardians[i]] = false;
        }
    }
}
