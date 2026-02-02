// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract VaultStaking {
    error amountCannotBeZero();
    error InsufficientBalance();
    error TransferFailed();

    IERC20 public immutable VAULT;
    IERC20 public immutable REWARD_TOKEN;
    uint256 public rewardRate; //This defines how fast rewards are emitted

    uint256 public totalStaked;
    mapping(address => uint256) public balanceOf;

    uint256 public rewardPerShareStored; //the reward timeline, how much reward one staked unit has earned so far
    uint256 public lastUpdateTime; //global clock to calculate how much reward has accrued since last update, Up to when have we already accounted rewards?

    mapping(address => uint256) public userRewardPerSharePaid; //the checkpoint, the point on the reward timeline (rewardPerShareStored) this user was last synced
    mapping(address => uint256) public rewards; // already-settled rewards, “wallet” of pending rewards.

    constructor(IERC20 _vault, IERC20 _rewardToken, uint256 _rewardRate) {
        VAULT = _vault;
        REWARD_TOKEN = _rewardToken;
        rewardRate = _rewardRate;
        lastUpdateTime = block.timestamp;
    }

    function stake(uint256 shares) external {
        if (shares == 0) {
            revert amountCannotBeZero();
        }

        updateReward(msg.sender);

        // pull vault shares from user
        if (!VAULT.transferFrom(msg.sender, address(this), shares)) {
            revert TransferFailed();
        }

        balanceOf[msg.sender] += shares;
        totalStaked += shares;
    }

    function withdraw(uint256 shares) external {
        if (shares == 0) {
            revert amountCannotBeZero();
        }

        if (balanceOf[msg.sender] < shares) {
            revert InsufficientBalance();
        }

        updateReward(msg.sender);

        balanceOf[msg.sender] -= shares;
        totalStaked -= shares;

        if (!VAULT.transfer(msg.sender, shares)) {
            revert TransferFailed();
        }
    }

    function getReward() external {
        updateReward(msg.sender); //First settle everything

        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0; // reset rewards of user, BEFORE transfer

        SafeERC20.safeTransfer(REWARD_TOKEN, msg.sender, reward); //transfer reward
    }

    //the catch-up function
    //bring reward timeline up to date, settle user rewards, move checkpoint
    function updateReward(address account) internal {
        rewardPerShareStored = rewardPerShare(); //Bring the global reward timeline up to now
        lastUpdateTime = block.timestamp; //We mark this is the moment we’re synced to

        if (account != address(0)) {
            rewards[account] = earned(account); //“settle rewards”, store everything the user earned so far.
            userRewardPerSharePaid[account] = rewardPerShareStored; //the new checkpoint, now only count rewards beyond this point.
        }
    }

    //Compute how much reward each vault share has earned
    //If we were to update rewards right now, where would the reward timeline be?
    function rewardPerShare() public view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerShareStored;
        }

        uint256 timeElapsed = block.timestamp - lastUpdateTime; //How much time passed since last sync
        uint256 rewardsGenerated = timeElapsed * rewardRate; //How many rewards entered the system?

        return rewardPerShareStored + (rewardsGenerated * 1e18) / totalStaked; //How much reward did ONE share earn?
    }

    // Rewards don’t start when you deposit. They are calculated when you interact.

    //How much reward history happened since user last checked?
    function earned(address account) public view returns (uint256) {
        uint256 userShares = balanceOf[account]; //user current shares

        uint256 rewardDelta = rewardPerShare() -
            userRewardPerSharePaid[account]; //How much of that history belongs to this user?

        return rewards[account] + (userShares * rewardDelta) / 1e18; //Already earned + newly earned
    }
}
