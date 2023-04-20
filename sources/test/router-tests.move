#[test_only]
module interest_protocol::router_tests {
  
  // use sui::test_scenario::{Self as test, Scenario, next_tx, ctx};
  // use sui::coin::{Self, mint_for_testing as mint, burn_for_testing as burn, CoinMetadata};
  // use sui::clock::{Self, Clock};

  // use interest_protocol::usdc::{Self, USDC};
  // use interest_protocol::usdt::{Self, USDT};
  // use interest_protocol::router;
  // use interest_protocol::dex::{Self, Storage};
  // use interest_protocol::test_utils::{people, scenario};

  // struct BTC {}
  // struct Ether {}

  // fun test_selects_volatile_if_no_stable_pool_(test: &mut Scenario) {
  //   let (alice, _) = people();

  //   let usdc_amount = 220000000 * 1000000;
  //   let btc_amount = 10000 * 1000000000;
    
  //   init_markets(test);

  //   next_tx(test, alice);
  //   {
  //       let storage = test::take_shared<Storage>(test);
  //       let clock_object = test::take_shared<Clock>(test);

  //       let lp_coin = dex::create_v_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<BTC>(btc_amount, ctx(test)),
  //         mint<USDC>(usdc_amount, ctx(test)),
  //         ctx(test)
  //       );

  //       burn(lp_coin);
  //       test::return_shared(clock_object);
  //       test::return_shared(storage);
  //   };

  //    next_tx(test, alice);
  //    {
  //    let storage = test::take_shared<Storage>(test);

  //     let pred = router::is_volatile_better<BTC, USDC>(
  //       &storage,
  //       2,
  //       0
  //     );

  //     assert!(pred, 0);
  //     test::return_shared(storage);
  //    }
  // }

  // #[test] 
  // fun test_selects_volatile_if_no_stable_pool() {
  //   let scenario = scenario();
  //   test_selects_volatile_if_no_stable_pool_(&mut scenario);
  //   test::end(scenario);
  // }

  // fun test_selects_stable_if_no_volatile_pool_(test: &mut Scenario) {
  //   let (alice, _) = people();

  //   let usdc_amount = 360000000 * 1000000;
  //   let usdt_amount = 360000000 * 1000000000;
    
  //   init_markets(test);
    
  //   next_tx(test, alice);
  //   {
  //    let storage = test::take_shared<Storage>(test);
  //    let clock_object = test::take_shared<Clock>(test);
  //    let usdc_coin_metadata = test::take_immutable<CoinMetadata<USDC>>(test);
  //    let usdt_coin_metadata = test::take_immutable<CoinMetadata<USDT>>(test);

  //     let lp_coin = dex::create_s_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<USDC>(usdc_amount, ctx(test)),
  //         mint<USDT>(usdt_amount, ctx(test)),
  //         &usdc_coin_metadata,
  //         &usdt_coin_metadata,
  //         ctx(test)
  //       );

  //       burn(lp_coin);

  //       test::return_shared(clock_object);        
  //       test::return_immutable(usdc_coin_metadata);
  //       test::return_immutable(usdt_coin_metadata);
  //       test::return_shared(storage);
  //   };

  //    next_tx(test, alice);
  //    {
  //     let storage = test::take_shared<Storage>(test);

  //     let pred = router::is_volatile_better<USDC, USDT>(
  //       &storage,
  //       2,
  //       0
  //     );

  //     assert!(!pred, 0);
  //     test::return_shared(storage);
  //    }
  // }

  // #[test] 
  // fun test_selects_stable_if_no_volatile_pool() {
  //   let scenario = scenario();
  //   test_selects_stable_if_no_volatile_pool_(&mut scenario);
  //   test::end(scenario);
  // }

  // fun test_selects_better_pool_(test: &mut Scenario) {
  //   let (alice, _) = people();

  //   // USDC buys more USDT in this pool
  //   let v_usdc_amount = 360000000 * 1000000;
  //   let v_usdt_amount = 400000000 * 1000000000;

  //   let s_usdc_amount = 360000000 * 1000000;
  //   let s_usdt_amount = 360000000 * 1000000000;
    
  //   init_markets(test);

  //   next_tx(test, alice);
  //   {
  //    let storage = test::take_shared<Storage>(test);
  //    let clock_object = test::take_shared<Clock>(test);     
  //    let usdc_coin_metadata = test::take_immutable<CoinMetadata<USDC>>(test);
  //    let usdt_coin_metadata = test::take_immutable<CoinMetadata<USDT>>(test);

  //     let lp_coin = dex::create_s_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<USDC>(s_usdc_amount, ctx(test)),
  //         mint<USDT>(s_usdt_amount, ctx(test)),
  //         &usdc_coin_metadata,
  //         &usdt_coin_metadata,
  //         ctx(test)
  //       );

  //       burn(lp_coin);
  //       test::return_shared(clock_object);           
  //       test::return_shared(storage);
  //       test::return_immutable(usdc_coin_metadata);
  //       test::return_immutable(usdt_coin_metadata);
  //   };

  //   next_tx(test, alice);
  //   {
  //    let storage = test::take_shared<Storage>(test);
  //    let clock_object = test::take_shared<Clock>(test);   

  //     let lp_coin = dex::create_v_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<USDC>(v_usdc_amount, ctx(test)),
  //         mint<USDT>(v_usdt_amount, ctx(test)),
  //         ctx(test)
  //       );

  //       burn(lp_coin);
  //       test::return_shared(clock_object);
  //       test::return_shared(storage);
  //   };

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let volatile_is_better = router::is_volatile_better<USDC, USDT>(&storage, v_usdc_amount / 10, 0);
  //     let volatile_is_not_better = router::is_volatile_better<USDC, USDT>(&storage, 0, v_usdt_amount/ 10);

  //     assert!(volatile_is_better, 0);
  //     assert!(!volatile_is_not_better, 0);

  //   test::return_shared(storage);
  //   }
  // }

  // #[test]
  // fun test_selects_better_pool() {
  //   let scenario = scenario();
  //   test_selects_better_pool_(&mut scenario);
  //   test::end(scenario);
  // }

  // fun test_swap_(test: &mut Scenario) {
  //   let (alice, _) = people();

  //   // USDC buys more USDT in this pool
  //   let usdc_amount = 360000000 * 1000000;
  //   let btc_amount = 400 * 1000000;
    
  //   init_markets(test);

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);   

  //     let lp_coins = dex::create_v_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<BTC>(btc_amount, ctx(test)),
  //         mint<USDC>(usdc_amount, ctx(test)),
  //         ctx(test)
  //     );

  //     burn(lp_coins);
  //     test::return_shared(clock_object);
  //     test::return_shared(storage);
  //   };

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);  

  //     let (coin_x, coin_y) = router::swap<BTC, USDC>(
  //       &mut storage,
  //       &clock_object,
  //       mint<BTC>(btc_amount / 10 , ctx(test)),
  //       coin::zero<USDC>(ctx(test)),
  //       0,
  //       ctx(test)
  //     );

  //     assert!(burn(coin_x) == 0, 0);
  //     assert!(burn(coin_y) > 0, 0);

  //     test::return_shared(clock_object);
  //     test::return_shared(storage);
  //   };

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);

  //     let (coin_x, coin_y) = router::swap<BTC, USDC>(
  //       &mut storage,
  //       &clock_object,
  //       coin::zero<BTC>(ctx(test)),
  //       mint<USDC>(usdc_amount / 10 , ctx(test)),
  //       0,
  //       ctx(test)
  //     );

  //     assert!(burn(coin_x) > 0, 0);
  //     assert!(burn(coin_y) == 0, 0);

  //     test::return_shared(clock_object);
  //     test::return_shared(storage);
  //   }
  // }

  // #[test]
  // fun test_swap() {
  //   let scenario = scenario();
  //   test_selects_better_pool_(&mut scenario);
  //   test::end(scenario);    
  // }

  // fun test_one_hop_swap_(test: &mut Scenario) {
  //   let (alice, _) = people();

  //   // First Pool (BTC/USDC)
  //   let usdc_amount = 360000000 * 1000000;
  //   let btc_amount = 400 * 1000000;

  //   // Second Pool (USDC/USDT)
  //   let usdt_amount = 360000000 * 1000000;

    
  //   init_markets(test);

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);

  //     burn(dex::create_v_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<BTC>(btc_amount, ctx(test)),
  //         mint<USDC>(usdc_amount, ctx(test)),
  //         ctx(test)
  //     ));

  //     burn(dex::create_v_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<USDC>(usdc_amount, ctx(test)),
  //         mint<USDT>(usdt_amount, ctx(test)),
  //         ctx(test)
  //     ));

  //     test::return_shared(clock_object);
  //     test::return_shared(storage);
  //   };

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);

  //     // BTC -> USDC -> USDT
  //     let (coin_x, coin_y) = router::one_hop_swap<BTC, USDT, USDC>(
  //       &mut storage,
  //       &clock_object,
  //       mint<BTC>(btc_amount / 10 , ctx(test)),
  //       coin::zero<USDT>(ctx(test)),
  //       0,
  //       ctx(test)
  //     );

  //     assert!(burn(coin_x) == 0, 0);
  //     assert!(burn(coin_y) > 0, 0);

  //     test::return_shared(clock_object);
  //     test::return_shared(storage);     
  //   };

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);

  //     // USDT -> USDC -> BTC
  //     let (coin_x, coin_y) = router::one_hop_swap<BTC, USDT, USDC>(
  //       &mut storage,
  //       &clock_object,
  //       coin::zero<BTC>(ctx(test)),
  //       mint<USDT>(usdt_amount / 10 , ctx(test)),
  //       0,
  //       ctx(test)
  //     );

  //     assert!(burn(coin_x) > 0, 0);
  //     assert!(burn(coin_y) == 0, 0);

  //     test::return_shared(clock_object);
  //     test::return_shared(storage);   
  //   }
  // }

  // #[test]
  // fun test_one_hop_swap() {
  //   let scenario = scenario();
  //   test_one_hop_swap_(&mut scenario);
  //   test::end(scenario);        
  // }

  // fun test_two_hop_swap_(test: &mut Scenario) {
  //   let (alice, _) = people();

  //   // First Pool (BTC/USDC)
  //   let usdc_amount = 360000000 * 1000000;
  //   let btc_amount = 400 * 1000000;

  //   // Second Pool (USDC/USDT)
  //   let usdt_amount = 360000000 * 1000000;

  //   // Third Pool (ETHER/USDT)
  //   let ether_amount = 2500 * 1000000;
    
  //   init_markets(test);

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);

  //     // Pool<BTC/USDC>
  //     burn(dex::create_v_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<BTC>(btc_amount, ctx(test)),
  //         mint<USDC>(usdc_amount, ctx(test)),
  //         ctx(test)
  //     ));

  //     // Pool<USDC/USDT>
  //     burn(dex::create_v_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<USDC>(usdc_amount, ctx(test)),
  //         mint<USDT>(usdt_amount, ctx(test)),
  //         ctx(test)
  //     ));

  //     // Pool<Ether/USDT>
  //     burn(dex::create_v_pool(
  //         &mut storage,
  //         &clock_object,
  //         mint<Ether>(ether_amount, ctx(test)),
  //         mint<USDT>(usdt_amount / 3, ctx(test)),
  //         ctx(test)
  //     ));

  //     test::return_shared(clock_object);
  //     test::return_shared(storage);
  //   };

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);

  //     // BTC -> USDC -> USDT -> Ether
  //     let (coin_x, coin_y) = router::two_hop_swap<BTC, Ether, USDT, USDC>(
  //       &mut storage,
  //       &clock_object,
  //       coin::zero<BTC>(ctx(test)),
  //       mint<Ether>(ether_amount / 10, ctx(test)),
  //       0,
  //       ctx(test)
  //     );

  //     assert!(burn(coin_x) > 0, 0);
  //     assert!(burn(coin_y) == 0, 0);

  //     test::return_shared(clock_object);
  //     test::return_shared(storage);        
  //   };

  //   next_tx(test, alice);
  //   {
  //     let storage = test::take_shared<Storage>(test);
  //     let clock_object = test::take_shared<Clock>(test);

  //     // BTC -> USDC -> USDT -> Ether
  //     let (coin_x, coin_y) = router::two_hop_swap<BTC, Ether, USDC, USDT>(
  //       &mut storage,
  //       &clock_object,
  //       mint<BTC>(btc_amount / 10 , ctx(test)),
  //       coin::zero<Ether>(ctx(test)),
  //       0,
  //       ctx(test)
  //     );

  //     assert!(burn(coin_x) == 0, 0);
  //     assert!(burn(coin_y) > 0, 0);

  //     test::return_shared(clock_object);
  //     test::return_shared(storage);         
  //   }        
  // }

  // #[test]
  // fun test_two_hop_swap() {
  //   let scenario = scenario();
  //   test_two_hop_swap_(&mut scenario);
  //   test::end(scenario);        
  // }

  // fun init_markets(test: &mut Scenario) {
  //   let (alice, _) = people();
  //   next_tx(test, alice);
  //   {
  //     dex::init_for_testing(ctx(test));
  //     usdc::init_for_testing(ctx(test));
  //     usdt::init_for_testing(ctx(test));
  //     clock::create_for_testing(ctx(test));
  //   };
  // }
}