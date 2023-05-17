// The governance token (SIP) of Interest Protocol
module liquidify_protocol::sip {
  use std::option;

  use sui::object::{Self, UID, ID};
  use sui::tx_context::{TxContext};
  use sui::balance::{Self, Balance};
  use sui::transfer;
  use sui::coin::{Self, Coin, TreasuryCap};
  use sui::url;
  use sui::vec_set::{Self, VecSet};
  use sui::tx_context;
  use sui::package::{Publisher};
  use sui::event::{emit};

  const SIP_PRE_MINT_AMOUNT: u64 = 10000000000000000; // 600M 60% of the supply

  // Errors
  const ERROR_NOT_ALLOWED_TO_MINT: u64 = 1;
  const ERROR_NOT_ENOUGH_BALANCE: u64 = 1;

  struct SIP has drop {}

  struct SIPStorage has key {
    id: UID,
    sip_balance: Balance<SIP>,
    minters: VecSet<ID> // List of publishers that are allowed to mint SIP
  }

  struct SIPAdminCap has key {
    id: UID
  }

  // Events 
  struct MinterAdded has copy, drop {
    id: ID
  }

  struct MinterRemoved has copy, drop {
    id: ID
  }

  fun init(witness: SIP, ctx: &mut TxContext) {
      // Create the SIP governance token with 9 decimals
      let (treasury, metadata) = coin::create_currency<SIP>(
            witness, 
            9,
            b"SIP",
            b"Siphon Token",
            b"Siphon Token",
            option::some(url::new_unsafe_from_bytes(b"https://liquidify.space/logo.png")),
            ctx
        );
      
      coin::mint_and_transfer(&mut treasury, SIP_PRE_MINT_AMOUNT, tx_context::sender(ctx), ctx);
      transfer::public_transfer(treasury, tx_context::sender(ctx));

      transfer::transfer(
        SIPAdminCap {
          id: object::new(ctx)
        },
        tx_context::sender(ctx)
      );

      transfer::share_object(
        SIPStorage {
          id: object::new(ctx),
          sip_balance:balance::zero<SIP>(),
          minters: vec_set::empty()
        }
      );

      // Freeze the metadata object
      transfer::public_freeze_object(metadata);
  }

    entry public fun sip_deposit(
      storage: &mut SIPStorage, 
      token: Coin<SIP>,
    ) {
    // Deposit the Coin<T> to the storage
      balance::join(&mut storage.sip_balance, coin::into_balance(token));
    } 

    entry public fun sip_withdraw(
      _treasury_cap: &mut TreasuryCap<SIP>,
      storage: &mut SIPStorage, 
      amount:u64,
      ctx: &mut TxContext
    ) {
        assert!(balance::value(&storage.sip_balance) >= amount, ERROR_NOT_ENOUGH_BALANCE);
        // Withdraw the Coin<T> from the Account
        let withdraw_coin = coin::take(&mut storage.sip_balance, amount, ctx);
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(withdraw_coin, sender);
    } 
  
  /**
    Contract mint
  * @dev Only minters can create new Coin<SIP>
  * @param storage The SIPStorage
  * @param publisher The Publisher object of the package who wishes to mint SIP
  * @return Coin<SIP> New created SIP coin
  */

  public fun mint(storage: &mut SIPStorage, publisher: &Publisher, value: u64, ctx: &mut TxContext): Coin<SIP> {
    assert!(is_minter(storage, object::id(publisher)), ERROR_NOT_ALLOWED_TO_MINT);
    coin::take(&mut storage.sip_balance, value, ctx)
  }
  

/**
    admin  mint
  * @dev Only minters can create new Coin<SIP>
  * @param storage The SIPStorage
  * @param publisher The Publisher object of the package who wishes to mint SIP
  * @return Coin<SIP> New created SIP coin
  */

  entry public fun admin_mint(treasury_cap: &mut TreasuryCap<SIP>,value: u64, ctx: &mut TxContext){
    coin::mint_and_transfer(treasury_cap, value, tx_context::sender(ctx), ctx)
  }

  /**
  * @dev A utility function to transfer SIP to a {recipient}
  * @param c The Coin<SIP> to transfer
  * @param recipient The recipient of the Coin<SIP>
  */
  public entry fun transfer(c: coin::Coin<SIP>, recipient: address) {
    transfer::public_transfer(c, recipient);
  }

  /**
  * @dev It returns the total supply of the Coin<X>
  * @param storage The {SIPStorage} shared object
  * @return the total supply in u64
  */
  entry public fun add_minter(_: &SIPAdminCap, storage: &mut SIPStorage, id: ID) {
    vec_set::insert(&mut storage.minters, id);
    emit(
      MinterAdded {
        id
      }
    );
  }

  /**
  * @dev It allows the holder of the {SIPAdminCap} to remove a minter. 
  * @param _ The SIPAdminCap to guard this function 
  * @param storage The SIPStorage shared object
  * @param publisher The package that will no longer be able to mint SIP
  *
  * It emits the  MinterRemoved event with the {ID} of the {Publisher}
  *
  */
  entry public fun remove_minter(_: &SIPAdminCap, storage: &mut SIPStorage, id: ID) {
    vec_set::remove(&mut storage.minters, &id);
    emit(
      MinterRemoved {
        id
      }
    );
  } 

  /**
  * @dev It indicates if a package has the right to mint SIP
  * @param storage The SIPStorage shared object
  * @param publisher of the package 
  * @return bool true if it can mint SIP
  */
  public fun is_minter(storage: &SIPStorage, id: ID): bool {
    vec_set::contains(&storage.minters, &id)
  }


  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(SIP {}, ctx);
  }
}