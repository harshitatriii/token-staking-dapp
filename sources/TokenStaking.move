module MyModule::TokenStaking {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;

    /// Struct representing a user's staking information
    struct StakingInfo has store, key {
        staked_amount: u64,     // Amount of tokens staked
        stake_time: u64,        // Timestamp when tokens were staked
        total_rewards: u64,     // Total rewards earned
    }

    /// Error codes
    const E_NO_STAKING_INFO: u64 = 1;
    const E_INSUFFICIENT_STAKE: u64 = 2;

    /// Function to stake tokens
    public fun stake_tokens(staker: &signer, amount: u64) acquires StakingInfo {
        let staker_addr = signer::address_of(staker);
        
        // Withdraw tokens from staker
        let stake_coins = coin::withdraw<AptosCoin>(staker, amount);
        coin::deposit<AptosCoin>(staker_addr, stake_coins);
        
        // Create or update staking info
        if (exists<StakingInfo>(staker_addr)) {
            let staking_info = borrow_global_mut<StakingInfo>(staker_addr);
            staking_info.staked_amount = staking_info.staked_amount + amount;
            staking_info.stake_time = timestamp::now_seconds();
        } else {
            let staking_info = StakingInfo {
                staked_amount: amount,
                stake_time: timestamp::now_seconds(),
                total_rewards: 0,
            };
            move_to(staker, staking_info);
        };
    }

    /// Function to unstake tokens and claim rewards
    public fun unstake_tokens(staker: &signer, amount: u64) acquires StakingInfo {
        let staker_addr = signer::address_of(staker);
        
        assert!(exists<StakingInfo>(staker_addr), E_NO_STAKING_INFO);
        
        let staking_info = borrow_global_mut<StakingInfo>(staker_addr);
        assert!(staking_info.staked_amount >= amount, E_INSUFFICIENT_STAKE);
        
        // Calculate rewards (simple 1% per day based on time staked)
        let time_staked = timestamp::now_seconds() - staking_info.stake_time;
        let rewards = (staking_info.staked_amount * time_staked) / (100 * 86400); // 1% daily
        
        // Update staking info
        staking_info.staked_amount = staking_info.staked_amount - amount;
        staking_info.total_rewards = staking_info.total_rewards + rewards;
        
        // Transfer unstaked amount + rewards back to staker
        let total_withdrawal = amount + rewards;
        let withdrawal_coins = coin::withdraw<AptosCoin>(staker, total_withdrawal);
        coin::deposit<AptosCoin>(staker_addr, withdrawal_coins);
    }
}