module liquidify_protocol::master_chef {
  use std::ascii::{String};

  use sui::object::{Self, UID};
  use sui::tx_context::{Self, TxContext};
  use sui::clock::{Self, Clock};
  use sui::balance::{Self, Balance};
  use sui::object_bag::{Self, ObjectBag};
  use sui::object_table::{Self, ObjectTable};
  use sui::table::{Self, Table};
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::event;
  use sui::package::{Self, Publisher};
  use sui::sui::SUI;

  use liquidify_protocol::sip::{Self, SIP, SIPStorage};
  use liquidify_protocol::utils::{get_coin_info_string};
  use liquidify_protocol::math::{fdiv_u256, fmul_u256};

  // TODO needs to be updated based on real time before mainnet
  const START_TIMESTAMP: u64 = 0;
  // TODO need to be updated to match the tokenomics
  const SIP_PER_MS: u64 = 12683; // 4M SIP per year
  const SIP_POOL_KEY: u64 = 0;

  const ERROR_POOL_ADDED_ALREADY: u64 = 1;
  const ERROR_NOT_ENOUGH_BALANCE: u64 = 2;
  const ERROR_NO_PENDING_REWARDS: u64 = 3;

  // OTW
  struct MASTER_CHEF has drop {}

  struct MasterChefStorage has key{
    id: UID,
    sip_per_ms: u64,
    total_allocation_points: u64,
    pool_keys: Table<String, PoolKey>,
    pools: ObjectTable<u64, Pool>,
    start_timestamp: u64,
    publisher: Publisher
  }

  struct Pool has key, store {
    id: UID,
    allocation_points: u64,
    last_reward_timestamp: u64,
    accrued_sip_per_share: u256,
    balance_value: u64,
    pool_key: u64
  }

  struct AccountStorage has key {
    id: UID,
    accounts: ObjectTable<u64, ObjectBag>
  }

  struct MasterChefBalanceStorage has key {
    id: UID,
    balance: Balance<SUI>,
  }

  struct Account has key, store {
    id: UID,
    // balance: Balance<T>,
    balance: u64,
    rewards_paid: u256,
    users:u64,
    referral_reward:u64,
    unclaimed_reward:u64,
  }

  struct PoolKey has store {
    key: u64
  }

  struct MasterChefAdmin has key {
    id: UID
  }

  // Events

  struct SetAllocationPoints<phantom T> has drop, copy {
    key: u64,
    allocation_points: u64,
  }

  struct AddPool<phantom T> has drop, copy {
    key: u64,
    allocation_points: u64,
  }

  struct Stake<phantom T> has drop, copy {
    sender: address,
    amount: u64,
    pool_key: u64,
    rewards: u64
  }

  struct Unstake<phantom T> has drop, copy {
    sender: address,
    amount: u64,
    pool_key: u64,
    rewards: u64
  }


  struct NewAdmin has drop, copy {
    admin: address
  }

  fun init(witness: MASTER_CHEF, ctx: &mut TxContext) {
      // Set up object_tables for the storage objects 
      let pools = object_table::new<u64, Pool>(ctx);  
      let pool_keys = table::new<String, PoolKey>(ctx);
      let accounts = object_table::new<u64, ObjectBag>(ctx);

      let coin_info_string = get_coin_info_string<SIP>();
      
      // Register the SIP farm in pool_keys
      table::add(
        &mut pool_keys, 
        coin_info_string, 
        PoolKey { 
          key: 0,
          }
        );

      // Register the Account object_bag
      object_table::add(
        &mut accounts,
         0,
        object_bag::new(ctx)
      );

      // Register the SIP farm on pools
      object_table::add(
        &mut pools, 
        0, // Key is the length of the object_bag before a new element is added 
        Pool {
          id: object::new(ctx),
          allocation_points: 1000,
          last_reward_timestamp: START_TIMESTAMP,
          accrued_sip_per_share: 0,
          balance_value: 0,
          pool_key: 0
          }
      );

      // Share MasterChefStorage
      transfer::share_object(
        MasterChefStorage {
          id: object::new(ctx),
          pools,
          sip_per_ms: SIP_PER_MS,
          total_allocation_points: 1000,
          pool_keys,
          start_timestamp: START_TIMESTAMP,
          publisher: package::claim(witness, ctx)
        }
      );

      // Share the Account Storage
      transfer::share_object(
        AccountStorage {
          id: object::new(ctx),
          accounts
        }
      );


      // Share the MasterChec Balance Storage
      transfer::share_object(
        MasterChefBalanceStorage {
          id: object::new(ctx),
          balance: balance::zero<SUI>(),
        }
      );

      // Give the admin_cap to the deployer
      transfer::transfer(MasterChefAdmin { id: object::new(ctx) }, tx_context::sender(ctx));
  }

/**
* @notice It returns the number of Coin<SIP> rewards an account is entitled to for T Pool
* @param storage The SIPStorage shared object
* @param accounts_storage The AccountStorage shared objetct
* @param account The function will return the rewards for this address
* @return rewards
*/
 public fun get_pending_rewards<T>(
  storage: &MasterChefStorage,
  account_storage: &AccountStorage,
  clock_oject: &Clock,
  account: address
  ): u256 {
    
    // If the user never deposited in T Pool, return 0
    if ((!object_bag::contains<address>(object_table::borrow(&account_storage.accounts, get_pool_key<T>(storage)), account))) return 0;

    // Borrow the pool
    let pool = borrow_pool<T>(storage);
    // Borrow the user account for T pool
    let account = borrow_account<T>(storage, account_storage, account);

    // Get the value of the total number of coins deposited in the pool
    let total_balance = (pool.balance_value as u256);
    // update this--------------
    // // Get the value of the number of coins deposited by the account
    // let account_balance_value = (balance::value(&account.balance) as u256);
    let account_balance_value = (account.balance as u256);

    // If the pool is empty or the user has no tokens in this pool return 0
    if (account_balance_value == 0 || total_balance == 0) return 0;

    // Save the current epoch in memory
    let current_timestamp = clock::timestamp_ms(clock_oject);
    // save the accrued sip per share in memory
    let accrued_sip_per_share = pool.accrued_sip_per_share;

    let is_sip = pool.pool_key == SIP_POOL_KEY;

    // If the pool is not up to date, we need to increase the accrued_sip_per_share
    if (current_timestamp > pool.last_reward_timestamp) {
      // Calculate how many epochs have passed since the last update
      let timestamp_delta = ((current_timestamp - pool.last_reward_timestamp) as u256);
      // Calculate the total rewards for this pool
      let rewards = (timestamp_delta * (storage.sip_per_ms as u256)) * (pool.allocation_points as u256) / (storage.total_allocation_points as u256);

      // Update the accrued_sip_per_share
      accrued_sip_per_share = accrued_sip_per_share + if (is_sip) {
        fdiv_u256(rewards, (pool.balance_value as u256))
          } else {
          (rewards / (pool.balance_value as u256))
          };
    };
    // Calculate the rewards for the user
    return if (is_sip) {
      fmul_u256(account_balance_value, accrued_sip_per_share) - account.rewards_paid
    } else {
      (account_balance_value * accrued_sip_per_share) - account.rewards_paid
    } 
  }

/**
* @notice It allows the caller to deposit Coin<T> in T Pool. It returns any pending rewards Coin<SIP>
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared object
* @param sip_storage The shared Object of SIP
* @param clock_object The Clock object created at genesis
* @param token The Coin<T>, the caller wishes to deposit
* @return Coin<SIP> pending rewards
*/
 public fun stake(
  storage: &mut MasterChefStorage, 
  balancestorage: &mut MasterChefBalanceStorage, 
  accounts_storage: &mut AccountStorage,
  sip_storage: &mut SIPStorage,
  referral:address,
  clock_object: &Clock,
  token: Coin<SUI>,
  ctx: &mut TxContext
 ): Coin<SIP> {

  // We need to update the pool rewards before any mutation
  update_pool<SUI>(storage, clock_object);
  // Save the sender in memory
  let sender = tx_context::sender(ctx);
  let key = get_pool_key<SUI>(storage);

   // Register the sender if it is his first time depositing in this pool 
  if (!object_bag::contains<address>(object_table::borrow(&accounts_storage.accounts, key), sender)) {
    object_bag::add(
      object_table::borrow_mut(&mut accounts_storage.accounts, key),
      sender,
      Account{
        id: object::new(ctx),
        balance: 0,
        rewards_paid: 0,
        users:0,
        referral_reward:0,
        unclaimed_reward:0
      }
    );
  };


 // Register the referral if it is his first time depositing in this pool 
  if (referral != @0x0 && referral != sender){
    if (!object_bag::contains<address>(object_table::borrow(&accounts_storage.accounts, key), referral)) {
      object_bag::add(
        object_table::borrow_mut(&mut accounts_storage.accounts, key),
        referral,
        Account{
          id: object::new(ctx),
          balance: 0,
          rewards_paid: 0,
          users:0,
          referral_reward:0,
          unclaimed_reward:0
        }
      );
    };
  };

  // Save in memory how mnay coins the sender wishes to deposit
  let token_value = coin::value(&token);


  // Get the needed info to fetch the sender account and the pool
  let pool = borrow_mut_pool<SUI>(storage);


  if (referral !=@0x0){
    update_account_referral<SUI>(accounts_storage, key, referral,token_value * 5 / 100);
  };

  let account = borrow_mut_account<SUI>(accounts_storage, key, sender);
  let is_sip = pool.pool_key == SIP_POOL_KEY;

  // Initiate the pending rewards to 0
  let pending_rewards = 0;
  
  // Save in memory the current number of coins the sender has deposited
  let account_balance_value = ((account.balance) as u256);

  // If he has deposited tokens, he has earned Coin<SIP>; therefore, we update the pending rewards based on the current balance
  if (account_balance_value > 0) pending_rewards = if (is_sip) {
    fmul_u256(account_balance_value, pool.accrued_sip_per_share)
  } else {
    (account_balance_value * pool.accrued_sip_per_share)
  } - account.rewards_paid;


  // Update the pool balance
  pool.balance_value = pool.balance_value + token_value;
  // update account balance
  if (referral != @0x0){
    account.balance = account.balance + token_value * 95 / 100;  
  } else{
    account.balance = account.balance + token_value;
  };

  // Update the Balance<T> on the sender account
  balance::join(&mut balancestorage.balance, coin::into_balance(token));
  // Consider all his rewards paid
  account.rewards_paid = if (is_sip) {
    fmul_u256(((account.balance) as u256), pool.accrued_sip_per_share)
  } else {
    ((account.balance) as u256) * pool.accrued_sip_per_share
  };

  event::emit(
    Stake<SUI> {
      pool_key: key,
      amount: token_value,
      sender,
      rewards: (pending_rewards as u64)
    }
  );

  // Mint Coin<SIP> rewards for the caller.
  sip::mint(sip_storage, &storage.publisher, (pending_rewards as u64), ctx)
 }


 /**
* @notice It allows the caller to withdraw Coin<T> from T Pool. It returns any pending rewards Coin<SIP>
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared objetct
* @param sip_storage The shared Object of SIP
* @param clock_object The Clock object created at genesis
* @param coin_value The value of the Coin<T>, the caller wishes to withdraw
* @return (Coin<SIP> pending rewards, Coin<T>)
*/
 entry public fun withdraw(
  _: &MasterChefAdmin,
  balancestorage: &mut MasterChefBalanceStorage, 
  coin_value: u64,
  ctx: &mut TxContext
 ){

  assert!(balance::value(&balancestorage.balance) >= coin_value, ERROR_NOT_ENOUGH_BALANCE);
  // Withdraw the Coin<T> from the Account
  let withdraw_coin = coin::take(&mut balancestorage.balance, coin_value, ctx);
  let sender = tx_context::sender(ctx);
  transfer::public_transfer(withdraw_coin, sender);
 } 


 entry public fun claim_reward(
  storage: &mut MasterChefStorage, 
  balancestorage: &mut MasterChefBalanceStorage, 
  accounts_storage: &mut AccountStorage,
  clock_object: &Clock,
  ctx: &mut TxContext
 ){

  update_pool<SUI>(storage, clock_object);
  
  // Get muobject_table struct of the Pool and Account
  let key = get_pool_key<SUI>(storage);
  let account = borrow_mut_account<SUI>(accounts_storage, key, tx_context::sender(ctx));
  assert!(account.unclaimed_reward > 0, ERROR_NOT_ENOUGH_BALANCE);
  let unclaimed_amount = account.unclaimed_reward;
  let unclaimed_coin = coin::take(&mut balancestorage.balance, unclaimed_amount, ctx);
  // Withdraw the Coin<T> from the Account
  let sender = tx_context::sender(ctx);
  transfer::public_transfer(unclaimed_coin, sender);
  account.unclaimed_reward = 0;
 } 

/**
* @notice it get current value for balance stroage. return u256
* @param _: &MasterChefAdmin, check if masterchef admin or not.
* @param balancestorage The balance storage address
* @return u256
*/

public fun get_currrent_value(
  balancestorage: &mut MasterChefBalanceStorage, 
 ):u256{
  let account_balance_value = (balance::value(&balancestorage.balance) as u256);
  account_balance_value
 } 


/**
* @notice It allows the caller to deposit Coin<T> from T Pool. It returns any pending rewards Coin<SIP>
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared objetct
* @param sip_storage The shared Object of SIP
* @param clock_object The Clock object created at genesis
* @param coin_value The value of the Coin<T>, the caller wishes to withdraw
* @return (Coin<SIP> pending rewards, Coin<T>)
*/
 entry public fun deposit(
  balancestorage: &mut MasterChefBalanceStorage, 
  token: Coin<SUI>,
 ) {
  // Deposit the Coin<T> to the storage
  balance::join(&mut balancestorage.balance, coin::into_balance(token));
 } 


/**
* @notice It allows the caller to withdraw Coin<T> from T Pool. It returns any pending rewards Coin<SIP>
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared objetct
* @param sip_storage The shared Object of SIP
* @param clock_object The Clock object created at genesis
* @param coin_value The value of the Coin<T>, the caller wishes to withdraw
* @return (Coin<SIP> pending rewards, Coin<T>)
*/
 public fun unstake(
  storage: &mut MasterChefStorage, 
  balancestorage: &mut MasterChefBalanceStorage, 
  accounts_storage: &mut AccountStorage,
  sip_storage: &mut SIPStorage,
  clock_object: &Clock,
  coin_value: u64,
  ctx: &mut TxContext
 ): (Coin<SIP>, Coin<SUI>) {
  // Need to update the rewards of the pool before any  mutation
  update_pool<SUI>(storage, clock_object);
  
  // Get muobject_table struct of the Pool and Account
  let key = get_pool_key<SUI>(storage);
  let pool = borrow_mut_pool<SUI>(storage);
  let account = borrow_mut_account<SUI>(accounts_storage, key, tx_context::sender(ctx));
  let is_sip = pool.pool_key == SIP_POOL_KEY;

  // Save the account balance value in memory
  let account_balance_value = (account.balance);

  // The user must have enough balance value
  assert!(account_balance_value >= coin_value, ERROR_NOT_ENOUGH_BALANCE);

  // Calculate how many rewards the caller is entitled to
  let pending_rewards = if (is_sip) {
    fmul_u256((account_balance_value as u256), pool.accrued_sip_per_share)
  } else {
    ((account_balance_value as u256) * pool.accrued_sip_per_share)
  } - account.rewards_paid;

  // Withdraw the Coin<T> from the Account
  let staked_coin = coin::take(&mut balancestorage.balance, coin_value, ctx);

  // Reduce the balance value in the pool
  pool.balance_value = pool.balance_value - coin_value;

  // Reduce the balance value in the account
  account.balance = account.balance - coin_value;

  // Consider all pending rewards paid
  account.rewards_paid = if (is_sip) {
    fmul_u256(((account.balance) as u256), pool.accrued_sip_per_share)
  } else {
    ((account.balance) as u256) * pool.accrued_sip_per_share
  };

  event::emit(
    Unstake<SUI> {
      pool_key: key,
      amount: coin_value,
      sender: tx_context::sender(ctx),
      rewards: (pending_rewards as u64)
    }
  );

  // Mint Coin<SIP> rewards and returns the Coin<T>
  (
    sip::mint(sip_storage, &storage.publisher, (pending_rewards as u64), ctx),
    staked_coin
  )
 } 

 /**
 * @notice It allows a caller to get all his pending rewards from T Pool
 * @param storage The MasterChefStorage shared object
 * @param accounts_storage The AccountStorage shared objetct
 * @param sip_storage The shared Object of SIP
 * @param clock_object The Clock object created at genesis
 * @return Coin<SIP> the pending rewards
 */
 public fun get_rewards<T>(
  storage: &mut MasterChefStorage, 
  accounts_storage: &mut AccountStorage,
  sip_storage: &mut SIPStorage,
  clock_object: &Clock,
  ctx: &mut TxContext
 ): Coin<SIP> {
  // Update the pool before any mutation
  update_pool<T>(storage, clock_object);
  
  // Get muobject_table Pool and Account structs
  let key = get_pool_key<T>(storage);
  let pool = borrow_pool<T>(storage);
  let account = borrow_mut_account<T>(accounts_storage, key, tx_context::sender(ctx));
  let is_sip = pool.pool_key == SIP_POOL_KEY;

  // Save the user balance value in memory
  let account_balance_value = ((account.balance) as u256);

  // Calculate how many rewards the caller is entitled to
  let pending_rewards = if (is_sip) {
    fmul_u256((account_balance_value as u256), pool.accrued_sip_per_share)
  } else {
    ((account_balance_value as u256) * pool.accrued_sip_per_share)
  } - account.rewards_paid;

  // No point to keep going if there are no rewards
  assert!(pending_rewards != 0, ERROR_NO_PENDING_REWARDS);
  
  // Consider all pending rewards paid
  account.rewards_paid = if (is_sip) {
    fmul_u256(((account.balance) as u256), pool.accrued_sip_per_share)
  } else {
    ((account.balance) as u256) * pool.accrued_sip_per_share
  };

  // Mint Coin<SIP> rewards to the caller
  sip::mint(sip_storage, &storage.publisher, (pending_rewards as u64), ctx)
 }

 /**
 * @notice Updates the reward info of all pools registered in this contract
 * @param storage The MasterChefStorage shared object
 */
 public fun update_all_pools(storage: &mut MasterChefStorage, clock_object: &Clock) {
  // Find out how many pools are in the contract
  let length = object_table::length(&storage.pools);

  // Index to keep track of how many pools we have updated
  let index = 0;

  // Save in memory key information before mutating the storage struct
  let sip_per_ms = storage.sip_per_ms;
  let total_allocation_points = storage.total_allocation_points;
  let start_timestamp = storage.start_timestamp;

  // Loop to iterate through all pools
  while (index < length) {
    // Borrow muobject_table Pool Struct
    let pool = object_table::borrow_mut(&mut storage.pools, index);

    // Update the pool
    update_pool_internal(pool, clock_object, sip_per_ms, total_allocation_points, start_timestamp);

    // Increment the index
    index = index + 1;
  }
 }  

 /**
 * @notice Updates the reward info for T Pool
 * @param storage The MasterChefStorage shared object
 */
 public fun update_pool<T>(storage: &mut MasterChefStorage, clock_object: &Clock) {
  // Save in memory key information before mutating the storage struct
  let sip_per_ms = storage.sip_per_ms;
  let total_allocation_points = storage.total_allocation_points;
  let start_timestamp = storage.start_timestamp;

  // Borrow muobject_table Pool Struct
  let pool = borrow_mut_pool<T>(storage);

  // Update the pool
  update_pool_internal(
    pool, 
    clock_object,
    sip_per_ms, 
    total_allocation_points, 
    start_timestamp
  );
 }

 /**
 * @dev The implementation of update_pool
 * @param pool T Pool Struct
 * @param sip_per_ms Value of Coin<SIP> this module mints per millisecond
 * @param total_allocation_points The sum of all pool points
 * @param start_timestamp The timestamp that this module is allowed to start minting Coin<SIP>
 */
 fun update_pool_internal(
  pool: &mut Pool, 
  clock_object: &Clock,
  sip_per_ms: u64, 
  total_allocation_points: u64,
  start_timestamp: u64
  ) {
  // Save the current epoch in memory  
  let current_timestamp = clock::timestamp_ms(clock_object);

  // If the pool reward info is up to date or it is not allowed to start minting return;
  if (current_timestamp == pool.last_reward_timestamp || start_timestamp > current_timestamp) return;

  // Save how many epochs have passed since the last update
  let timestamp_delta = current_timestamp - pool.last_reward_timestamp;

  // Update the current pool last reward timestamp
  pool.last_reward_timestamp = current_timestamp;

  // There is nothing to do if the pool is not allowed to mint Coin<SIP> or if there are no coins deposited on it.
  if (pool.allocation_points == 0 || pool.balance_value == 0) return;

  // Calculate the rewards (pool_allocation * milliseconds * sip_per_epoch) / total_allocation_points
  let rewards = ((pool.allocation_points as u256) * (timestamp_delta as u256) * (sip_per_ms as u256) / (total_allocation_points as u256));

  // Update the accrued_sip_per_share
  pool.accrued_sip_per_share = pool.accrued_sip_per_share + if (pool.pool_key == SIP_POOL_KEY) {
    fdiv_u256(rewards, (pool.balance_value as u256))
  } else {
    (rewards / (pool.balance_value as u256))
  };
 }

 /**
 * @dev The updates the allocation points of the SIP Pool and the total allocation points
 * The SIP Pool must have 1/3 of all other pools allocations
 * @param storage The MasterChefStorage shared object
 */
 fun update_sip_pool(storage: &mut MasterChefStorage) {
    // Save the total allocation points in memory
    let total_allocation_points = storage.total_allocation_points;

    // Borrow the SIP muobject_table pool struct
    let pool = borrow_mut_pool<SIP>(storage);

    // Get points of all other pools
    let all_other_pools_points = total_allocation_points - pool.allocation_points;

    // Divide by 3 to get the new sip pool allocation
    let new_sip_pool_allocation_points = all_other_pools_points / 3;

    // Calculate the total allocation points
    let total_allocation_points = total_allocation_points + new_sip_pool_allocation_points - pool.allocation_points;

    // Update pool and storage
    pool.allocation_points = new_sip_pool_allocation_points;
    storage.total_allocation_points = total_allocation_points;
 } 

  /**
  * @dev Finds T Pool from MasterChefStorage
  * @param storage The SIPStorage shared object
  * @return muobject_table T Pool
  */
 fun borrow_mut_pool<T>(storage: &mut MasterChefStorage): &mut Pool {
  let key = get_pool_key<T>(storage);
  object_table::borrow_mut(&mut storage.pools, key)
 }

/**
* @dev Finds T Pool from MasterChefStorage
* @param storage The SIPStorage shared object
* @return immuobject_table T Pool
*/
public fun borrow_pool<T>(storage: &MasterChefStorage): &Pool {
  let key = get_pool_key<T>(storage);
  object_table::borrow(&storage.pools, key)
 }

/**
* @dev Finds the key of a pool
* @param storage The MasterChefStorage shared object
* @return the key of T Pool
*/
 fun get_pool_key<T>(storage: &MasterChefStorage): u64 {
    table::borrow<String, PoolKey>(&storage.pool_keys, get_coin_info_string<T>()).key
 }

/**
* @dev Finds an Account struct for T Pool
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared object
* @param sender The address of the account we wish to find
* @return immuobject_table AccountStruct of sender for T Pool
*/ 
 public fun borrow_account<T>(storage: &MasterChefStorage, accounts_storage: &AccountStorage, sender: address): &Account {
  object_bag::borrow(object_table::borrow(&accounts_storage.accounts, get_pool_key<T>(storage)), sender)
 }


/**
* @dev Finds an Account struct for T Pool
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared object
* @param sender The address of the account we wish to find
* @return immuobject_table AccountStruct of sender for T Pool
*/ 
 public fun account_exists<T>(storage: &MasterChefStorage, accounts_storage: &AccountStorage, sender: address): bool {
  object_bag::contains(object_table::borrow(&accounts_storage.accounts, get_pool_key<T>(storage)), sender)
 }

/**
* @dev Finds an Account struct for T Pool
* @param accounts_storage The AccountStorage shared object
* @param sender The address of the account we wish to find
* @return muobject_table AccountStruct of sender for T Pool
*/ 
fun borrow_mut_account<T>(accounts_storage: &mut AccountStorage, key: u64, sender: address): &mut Account {
  object_bag::borrow_mut(object_table::borrow_mut(&mut accounts_storage.accounts, key), sender)
 }

 /**
* @dev Update accont balance
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared object
* @param sender The address of the account we wish to find
* @return immuobject_table AccountStruct of sender for T Pool
*/ 
 fun update_account_referral<T>(accounts_storage: &mut AccountStorage, key: u64, sender: address,added_amount:u64) {
  let account:&mut Account = object_bag::borrow_mut(object_table::borrow_mut(&mut accounts_storage.accounts, key), sender);
  account.referral_reward = account.referral_reward + added_amount;
  account.unclaimed_reward = account.unclaimed_reward + added_amount;
  account.users = account.users + 1;
 }

/**
* @dev Updates the value of Coin<SIP> this module is allowed to mint per millisecond
* @param _ the admin cap
* @param storage The MasterChefStorage shared object
* @param sip_per_ms the new sip_per_ms
* Requirements: 
* - The caller must be the admin
*/ 
 entry public fun update_sip_per_ms(
  _: &MasterChefAdmin,
  storage: &mut MasterChefStorage,
  clock_object: &Clock,
  sip_per_ms: u64
  ) {
    // Update all pools rewards info before updating the sip_per_epoch
    update_all_pools(storage, clock_object);
    storage.sip_per_ms = sip_per_ms;
 }

/**
* @dev Register a Pool for Coin<T> in this module
* @param _ the admin cap
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared object
* @param allocaion_points The allocation points of the new T Pool
* @param update if true we will update all pools rewards before any update
* Requirements: 
* - The caller must be the admin
* - Only one Pool per Coin<T>
*/ 
 entry public fun add_pool<T>(
  _: &MasterChefAdmin,
  storage: &mut MasterChefStorage,
  accounts_storage: &mut AccountStorage,
  clock_object: &Clock,
  allocation_points: u64,
  ctx: &mut TxContext
 ) {
  // Save total allocation points and start epoch in memory
  let total_allocation_points = storage.total_allocation_points;
  let start_timestamp = storage.start_timestamp;
  // Update all pools if true
  update_all_pools(storage, clock_object);

  let coin_info_string = get_coin_info_string<T>();

  // Make sure Coin<T> has never been registered
  assert!(!table::contains(&storage.pool_keys, coin_info_string), ERROR_POOL_ADDED_ALREADY);

  // Update the total allocation points
  storage.total_allocation_points = total_allocation_points + allocation_points;

  // Current number of pools is the key of the new pool
  let key = table::length(&storage.pool_keys);

  // Register the Account object_bag
  object_table::add(
    &mut accounts_storage.accounts,
    key,
    object_bag::new(ctx)
  );

  // Register the PoolKey
  table::add(
    &mut storage.pool_keys,
    coin_info_string,
    PoolKey {
      key
    }
  );

  // Save the current_epoch in memory
  let current_timestamp = clock::timestamp_ms(clock_object);

  // Register the Pool in SIPStorage
  object_table::add(
    &mut storage.pools,
    key,
    Pool {
      id: object::new(ctx),
      allocation_points,
      last_reward_timestamp: if (current_timestamp > start_timestamp) { current_timestamp } else { start_timestamp },
      accrued_sip_per_share: 0,
      balance_value: 0,
      pool_key: key
    }
  );

  // Emit
  event::emit(
    AddPool<T> {
      key,
      allocation_points
    }
  );

  // Update the SIP Pool allocation
  update_sip_pool(storage);
 }

/**
* @dev Updates the allocation points for T Pool
* @param _ the admin cap
* @param storage The MasterChefStorage shared object
* @param allocation_points The new allocation points for T Pool
* @param update if true we will update all pools rewards before any update
* Requirements: 
* - The caller must be the admin
* - The Pool must exist
*/ 
 entry public fun set_allocation_points<T>(
  _: &MasterChefAdmin,
  storage: &mut MasterChefStorage,
  clock_object: &Clock,
  allocation_points: u64,
  update: bool
 ) {
  // Save the total allocation points in memory
  let total_allocation_points = storage.total_allocation_points;
  // Update all pools
  if (update) update_all_pools(storage, clock_object);

  // Get Pool key and Pool muobject_table Struct
  let key = get_pool_key<T>(storage);
  let pool = borrow_mut_pool<T>(storage);

  // No point to update if the new allocation_points is not different
  if (pool.allocation_points == allocation_points) return;

  // Update the total allocation points
  let total_allocation_points = total_allocation_points + allocation_points - pool.allocation_points;

  // Update the T Pool allocation points
  pool.allocation_points = allocation_points;
  // Update the total allocation points
  storage.total_allocation_points = total_allocation_points;

  event::emit(
    SetAllocationPoints<T> {
      key,
      allocation_points
    }
  );

  // Update the SIP Pool allocation points
  update_sip_pool(storage);
 }
 
 /**
 * @notice It allows the admin to transfer the AdminCap to a new address
 * @param admin The SIPAdmin Struct
 * @param recipient The address of the new admin
 */
 entry public fun transfer_admin(
  admin: MasterChefAdmin,
  recipient: address
 ) {
  transfer::transfer(admin, recipient);
  event::emit(NewAdmin { admin: recipient })
 }

 /**
 * @notice A getter function
 * @param storage The MasterChefStorage shared object
 * @param accounts_storage The AccountStorage shared object
 * @param sender The address we wish to check
 * @return balance of the account on T Pool and rewards paid 
 */
 public fun get_account_info(storage: &MasterChefStorage, accounts_storage: &AccountStorage, sender: address): (u64, u256) {
    let account = object_bag::borrow<address, Account>(object_table::borrow(&accounts_storage.accounts, get_pool_key<SUI>(storage)), sender);
    (
      account.balance,
      account.rewards_paid,
    )
  }


public fun get_account_detail(storage: &MasterChefStorage, accounts_storage: &AccountStorage, sender: address): (u64, u256,u64,u64,u64) {
    let account = object_bag::borrow<address, Account>(object_table::borrow(&accounts_storage.accounts, get_pool_key<SUI>(storage)), sender);
    (
      account.balance,
      account.rewards_paid,
      account.users,
      account.referral_reward,
      account.unclaimed_reward
    )
  }


/**
 * @notice A getter function
 * @param storage The MasterChefStorage shared object
 * @return allocation_points, last_reward_timestamp, accrued_sip_per_share, balance_value of T Pool
 */
  public fun get_pool_info<T>(storage: &MasterChefStorage): (u64, u64, u256, u64) {
    let key = get_pool_key<T>(storage);
    let pool = object_table::borrow(&storage.pools, key);
    (
      pool.allocation_points,
      pool.last_reward_timestamp,
      pool.accrued_sip_per_share,
      pool.balance_value
    )
  }

  /**
 * @notice A getter function
 * @param storage The MasterChefStorage shared object
 * @return total sip_per_ms, total_allocation_points, start_timestamp
 */
  public fun get_master_chef_storage_info(storage: &MasterChefStorage): (u64, u64, u64) {
    (
      storage.sip_per_ms,
      storage.total_allocation_points,
      storage.start_timestamp
    )
  }
  
}
