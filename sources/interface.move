// Entry functions for Interest Protocol
// TODO ADD FUNCTIONS FOR WHIRPOOL
module liquidify_protocol::interface {
  use std::vector;

  use sui::coin::{Coin};
  use sui::tx_context::{Self, TxContext};
  use sui::transfer;
  use sui::clock::{Clock};

  use liquidify_protocol::master_chef::{Self, MasterChefStorage, AccountStorage as MasterChefAccountStorage,MasterChefBalanceStorage};
  use liquidify_protocol::sip::{SIPStorage};
  use sui::sui::SUI;
  const ERROR_TX_DEADLINE_REACHED: u64 = 1;


/**
* @notice It allows a user to deposit a Coin<T> in a farm to earn Coin<SIP>. 
* @param storage The MasterChefStorage shared object
* @param balanceStorage The Masterchef Balance storage shared object
* @param accounts_storage The MasterChefAccountStorage shared object
* @param sip_storage The shared Object of SIP
* @param clock_object The Clock object created at genesis
* @param vector_token  A list of Coin<Y>, the contract will merge all coins into with the `coin_y_amount` and return any extra value 
* @param coin_token_amount The desired amount of Coin<X> to send
*/
  entry public fun stake(
    storage: &mut MasterChefStorage,
    balancestorage: &mut MasterChefBalanceStorage, 
    accounts_storage: &mut MasterChefAccountStorage,
    sip_storage: &mut SIPStorage,
    referral:address,
    clock_object: &Clock,
    token: Coin<SUI>,
    ctx: &mut TxContext
  ) {

    // Create a coin from the vector. It keeps the desired amound and sends any extra coins to the caller
    // vector total value - coin desired value
    // Stake and send Coin<SIP> rewards to the caller.
    transfer::public_transfer(
      master_chef::stake(
        storage,
        balancestorage,
        accounts_storage,
        sip_storage,
        referral,
        clock_object,
        token,
        ctx
      ),
      tx_context::sender(ctx)
    );
  }

/**
* @notice It allows a user to withdraw an amount of Coin<T> from a farm. 
* @param storage The MasterChefStorage shared object
* @param accounts_storage The MasterChefAccountStorage shared object
* @param sip_storage The shared Object of SIP
* @param clock_object The Clock object created at genesis
* @param coin_value The amount of Coin<T> the caller wishes to withdraw
*/
  entry public fun unstake(
    storage: &mut MasterChefStorage,
    balancestorage: &mut MasterChefBalanceStorage, 
    accounts_storage: &mut MasterChefAccountStorage,
    sip_storage: &mut SIPStorage,
    clock_object: &Clock,
    coin_value: u64,
    ctx: &mut TxContext
  ) {
    let sender = tx_context::sender(ctx);
    // Unstake yields Coin<SIP> rewards.
    let (coin_sip, coin) = master_chef::unstake(
        storage,
        balancestorage,
        accounts_storage,
        sip_storage,
        clock_object,
        coin_value,
        ctx
    );
    transfer::public_transfer(coin_sip, sender);
    transfer::public_transfer(coin, sender);
  }

/**
* @notice It allows a user to withdraw his/her rewards from a specific farm. 
* @param storage The MasterChefStorage shared object
* @param accounts_storage The AccountStorage shared object
* @param sip_storage The shared Object of sip
* @param clock_object The Clock object created at genesis
*/
  entry public fun get_rewards<T>(
    storage: &mut MasterChefStorage,
    accounts_storage: &mut MasterChefAccountStorage,
    sip_storage: &mut SIPStorage,
    clock_object: &Clock,
    ctx: &mut TxContext   
  ) {
    transfer::public_transfer(master_chef::get_rewards<T>(storage, accounts_storage, sip_storage, clock_object, ctx) ,tx_context::sender(ctx));
  }

/**
* @notice It updates the Coin<T> farm rewards calculation.
* @param storage The MasterChefStorage shared object
* @param clock_object The Clock object created at genesis
*/
  entry public fun update_pool<T>(storage: &mut MasterChefStorage, clock_object: &Clock) {
    master_chef::update_pool<T>(storage, clock_object);
  }

/**
* @notice It updates all pools.
* @param storage The MasterChefStorage shared object
* @param clock_object The Clock object created at genesis
*/
  entry public fun update_all_pools(storage: &mut MasterChefStorage, clock_object: &Clock) {
    master_chef::update_all_pools(storage, clock_object);
  }

  /**
  * @dev A utility function to return to the frontend the allocation, pool_balance and _account balance of farm for Coin<X>
  * @param storage The MasterChefStorage shared object
  * @param accounts_storage the MasterChefAccountStorage shared object of the masterchef contract
  * @param account The account of the user that has Coin<X> in the farm
  * @param farm_vector The list of farm data we will be mutation/adding
  */
  fun get_farm<X>(
    storage: &MasterChefStorage,
    accounts_storage: &MasterChefAccountStorage,
    account: address,
    farm_vector: &mut vector<vector<u64>>
  ) {
     let inner_vector = vector::empty<u64>();
    let (allocation, _, _, pool_balance) = master_chef::get_pool_info<X>(storage);

    vector::push_back(&mut inner_vector, allocation);
    vector::push_back(&mut inner_vector, pool_balance);

    if (master_chef::account_exists<X>(storage, accounts_storage, account)) {
      let (account_balance, _,) = master_chef::get_account_info(storage, accounts_storage, account);
      vector::push_back(&mut inner_vector, account_balance);
    } else {
      vector::push_back(&mut inner_vector, 0);
    };

    vector::push_back(farm_vector, inner_vector);
  }

  /**
  * @dev The implementation of the get_farm function. It collects information for ${num_of_farms}.
  * @param storage The MasterChefStorage shared object
  * @param accounts_storage the MasterChefAccountStorage shared object of the masterchef contract
  * @param account The account of the user that has Coin<X> in the farm
  * @param num_of_farms The number of farms we wish to collect data from for a maximum of 5
  */
  public fun get_farms<A, B, C, D, E>(
    storage: &MasterChefStorage,
    accounts_storage: &MasterChefAccountStorage,
    account: address,
    num_of_farms: u64
  ): vector<vector<u64>> {
    let farm_vector = vector::empty<vector<u64>>(); 

    get_farm<A>(storage, accounts_storage, account, &mut farm_vector);

    if (num_of_farms == 1) return farm_vector;

    get_farm<B>(storage, accounts_storage, account, &mut farm_vector);

    if (num_of_farms == 2) return farm_vector;

    get_farm<C>(storage, accounts_storage, account, &mut farm_vector);

    if (num_of_farms == 3) return farm_vector;

    get_farm<D>(storage, accounts_storage, account, &mut farm_vector);

    if (num_of_farms == 4) return farm_vector;

    get_farm<E>(storage, accounts_storage, account, &mut farm_vector);

    if (num_of_farms == 5) return farm_vector;

    farm_vector
  }
}