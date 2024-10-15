predicate; 

use std::{
    auth::predicate_address,
    inputs::{
        Input, input_coin_owner, input_count, input_type, input_asset_id
    },
    outputs::{
        Output, output_amount, output_type, GTF_OUTPUT_COIN_TO, GTF_OUTPUT_COIN_ASSET_ID, output_count
    },
    tx::{tx_tip},
};

// Define configurable constants
configurable {
    BASE_ASSET: AssetId = AssetId::from(0xf8f8b6283d7fa5b672b530cbb84fcccb4ff8dc40f8176ef4544ddb1f1952ad07),
    USDT: AssetId = AssetId::from(0xe6bf905e4492a0d3e562ca00e8bcb85c7d764443728e7d105fcd63e00e393c9d),
    YES: AssetId = AssetId::from(0x6036a3f55d888d2c9da23c4e64bc2d9de2e770499974293a7bca4d1eb1c793ff),
    NO: AssetId = AssetId::from(0x864b23e3bf2d3d0cc97c549d2212a400682f40cd8605b91002743c4873cd9074),
    ORACLE: Address = Address::from(0x6b63804cfbf9856e68e5b6e7aef238dc8311ec55bec04df774003a2c96e0418e),
    REDEMPTION_YES: Address = Address::from(0x6b63804cfbf9856e68e5b6e7aef238dc8311ec55bec04df774003a2c96e0418e),
    REDEMPTION_NO: Address = Address::from(0x6b63804cfbf9856e68e5b6e7aef238dc8311ec55bec04df774003a2c96e0418e),
    VRF: AssetId = AssetId::from(0x864b23e3bf2d3d0cc97c549d2212a400682f40cd8605b91002743c4873cd9074),
    FEES: u64 = 100_000,
}

const zero_address = Address::zero();

fn main() -> bool {
    
    let reserve_predicate = predicate_address().unwrap();
    let output_count = output_count();

    // Ensure no tip is added
    if tx_tip().is_some() {
        return false;
    }

    let case = get_case();

    if (case == 1) {
        return handle_redemption(reserve_predicate) && output_count == 8; 
    }
    else if (case == 2) {
        return handle_voting_or_cancel(reserve_predicate,output_count);
    }
    return false;
}

fn handle_redemption(reserve_predicate: Address) -> bool {
    // REDEMPTION FLOW
    // There are 8 outputs for a redemption transaction
    // 0th output is of type Change - (VRF)
    // 1st output is of type Change - (USDT)
    // 2nd output is of type Coin - (USDT)
    // 3rd output is of type Coin - (YES)
    // 4th output is of type Coin - (NO)
    // 5th output is of type Change - (ETH / Base Asset)
    // 6th output is of type Change - (YES)
    // 7th output is of type Change - (NO)

    // The checks on output_to are : 
    // USDT Coin (Output 2) must go to REDEMPTION_YES or REDEMPTION_NO 
    // YES Coin (Output 3) & NO Coin (Output 4) must go to ZERO ADDRESS
    // YES Change (Output 6) & NO Change (Output 7) must go to ZERO ADDRESS
    // USDT Change (Output 1) must go to reserve predicate
    
    return 
    // OUTPUT VALIDATIONS
    validate_output(0, VRF, 2) && validate_output(1, USDT, 2) 
    && validate_output(2, USDT, 0) && validate_output(3, YES, 0) && validate_output(4, NO, 0) 
    && validate_output(5, BASE_ASSET, 2) && validate_output(6, YES, 2) && validate_output(7, NO, 2) 
    // OUTPUT_TO_VALIDATIONS
    && (validate_output_to(2,REDEMPTION_YES,0) || validate_output_to(2,REDEMPTION_NO,0))
    && validate_output_to(3,zero_address,0) && validate_output_to(4,zero_address,0) 
    && validate_output_to(6,zero_address,2) && validate_output_to(7,zero_address,2) 
    && validate_output_to(1,reserve_predicate,2);
}

fn handle_voting_or_cancel(reserve_predicate: Address, output_count: u16) -> bool {
    let voting = validate_voting(reserve_predicate) && output_count == 9;
    let cancellation = validate_cancel(reserve_predicate)  && output_count == 8;
    return validate_voting_or_cancel_outputs() && (voting || cancellation);
}

fn validate_voting_or_cancel_outputs() -> bool {
    // There are 9 outputs for a voting transaction 
    // and 8 outputs for cancellation
    // However some are common

    // COMMON
    // 0th output is of type Change - (VRF)
    // 1st output is of type Change - (USDT)
    // 2nd output is of type Change - (YES)
    // 3rd output is of type Change - (NO)
    // 4th output is of type Coin - (USDT)
    
    // VOTING
    // 5th output is of type Coin - (USDT) - FEES to admin
    // 6th output is of type Coin - (YES)
    // 7th output is of type Coin - (NO)
    // 8th output is of type Change - (ETH)

    // CANCELLATION
    // 5th output is of type Coin - (YES)
    // 6th output is of type Coin - (NO)
    // 7th output is of type Change - (ETH)
    
    return // OUTPUT VALIDATIONS
    validate_output(0, VRF, 2) && validate_output(1, USDT, 2) 
    && validate_output(2, YES, 2) && validate_output(3, NO, 2) 
    && validate_output(4, USDT, 0);
}

fn validate_voting(reserve_predicate: Address) -> bool {
    // VOTING
    // 5th output is of type Coin - (USDT) - FEES to admin
    // 6th output is of type Coin - (YES)
    // 7th output is of type Coin - (NO)
    // 8th output is of type Change - (ETH)

    // The checks on output_to are : 
    // YES Change (Output 2) must go to reserve predicate
    // NO Change (Output 3) must go to reserve predicate
    // USDT Coin (Output 4) must go to reserve predicate
    // USDT Coin (Output 5) must go to oracle - FEES
    // ETH Change (Output 8) must go to reserve predicate
    // USDT Coin (Output 4) == YES Coin (Output 6)
    // USDT Coin (Output 4) == NO Coin (Output 7)
    // USDT Coin (Output 5) == FEES
    
    let USDT_amount = output_amount(4).unwrap();

    return 
    // OUTPUT VALIDATIONS
    validate_output(5, USDT, 0) 
    && validate_output(6, YES, 0) && validate_output(7, NO, 0) 
    && validate_output(8, BASE_ASSET, 2)
    // OUTPUT TO VALIDATIONS
    && validate_output_to(2,reserve_predicate,2) && validate_output_to(3,reserve_predicate,2)
    && validate_output_to(4,reserve_predicate,0) && validate_output_to(5,ORACLE,0)
    && validate_output_to(8,reserve_predicate,2)
    // AMOUNT VALIDATIONS
    && USDT_amount == output_amount(6).unwrap() && USDT_amount == output_amount(7).unwrap()
    && output_amount(5).unwrap() >= FEES;
}

fn validate_cancel(reserve_predicate: Address) -> bool {
    // CANCELLATION
    // 5th output is of type Coin - (YES)
    // 6th output is of type Coin - (NO)
    // 7th output is of type Change - (ETH)

    // The checks on output_to are : 
    // USDT Change (Output 1) must go to reserve predicate
    // YES Coin (Output 5) must go to reserve predicate
    // NO Coin (Output 6) must go to reserve predicate
    // ETH Change (Output 7) must go to reserve predicate
    // USDT Coin (Output 4) == YES Coin (Output 5)
    // USDT Coin (Output 4) == NO Coin (Output 6)

    let USDT_amount = output_amount(4).unwrap();

    return 
    // OUTPUT VALIDATIONS
    validate_output(5, YES, 0) && validate_output(6, NO, 0) 
    && validate_output(7, BASE_ASSET, 2)
    // OUTPUT TO VALIDATIONS
    && validate_output_to(1,reserve_predicate,2)
    && validate_output_to(5,reserve_predicate,0) && validate_output_to(6,reserve_predicate,0)
    && validate_output_to(7,reserve_predicate,2)
    // AMOUNT VALIDATIONS
    && USDT_amount == output_amount(5).unwrap() && USDT_amount == output_amount(6).unwrap();
}

fn validate_output(index: u64, expected_asset_id: AssetId, expected_asset_type: u64) -> bool {
    match output_type(index) {
        Some(Output::Coin) => output_asset_id(index) == expected_asset_id && expected_asset_type == 0,
        Some(Output::Change) => output_asset_id(index) == expected_asset_id && expected_asset_type == 2,
        _ => false,
    }
}

fn validate_output_to(index: u64, expected_address_to: Address, expected_asset_type: u64) -> bool {
    match output_type(index) {
        Some(Output::Coin) => output_asset_to(index) == expected_address_to && expected_asset_type == 0,
        Some(Output::Change) => output_asset_to(index) == expected_address_to && expected_asset_type == 2,
        _ => false,
    }
}

pub fn output_asset_id(index: u64) -> AssetId {
    return AssetId::from(__gtf::<b256>(index, GTF_OUTPUT_COIN_ASSET_ID));
}

pub fn output_asset_to(index: u64) -> Address {
    return Address::from(__gtf::<b256>(index, GTF_OUTPUT_COIN_TO));
}

fn get_case() -> u64 {
    if input_count() == 0 {
        return 0;
    }
    if input_type(0).unwrap() != Input::Coin {
        return 0;
    }
    if input_asset_id(0).unwrap() != VRF {
        return 0;
    };
    if input_coin_owner(0).unwrap() == ORACLE {
        return 1;
    } else {
        return 2;
    }
}