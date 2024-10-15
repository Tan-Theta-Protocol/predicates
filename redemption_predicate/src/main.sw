predicate;

// Import necessary modules and functions
use std::{
    auth::predicate_address,
    outputs::{
        Output,
        output_amount,
        output_type,
        output_count,
        GTF_OUTPUT_COIN_TO,
        GTF_OUTPUT_COIN_ASSET_ID
    },
};

// Define configurable constants
configurable {
    // Asset ID for USDT (The asset to be paid)
    USDT: AssetId = AssetId::from(0x0101010101010101010101010101010101010101010101010101010101010101),
    // Asset ID for winning asset
    WINNING_ASSET: AssetId = AssetId::from(0x0101010101010101010101010101010101010101010101010101010101010101),
    // Asset ID for losing asset
    YES: AssetId = AssetId::from(0x0101010101010101010101010101010101010101010101010101010101010101),
    NO: AssetId = AssetId::from(0x0101010101010101010101010101010101010101010101010101010101010101),
    // Base Asset Id
    BASE_ASSET: AssetId = AssetId::from(0xf8f8b6283d7fa5b672b530cbb84fcccb4ff8dc40f8176ef4544ddb1f1952ad07),
    COMMISSION_PERCENTAGE: u64 = 0,
    VRF: AssetId = AssetId::from(0xf8f8b6283d7fa5b672b530cbb84fcccb4ff8dc40f8176ef4544ddb1f1952ad07),
    ORACLE: Address = Address::from(0x6b63804cfbf9856e68e5b6e7aef238dc8311ec55bec04df774003a2c96e0418e),
}

// Main predicate function
fn main() -> bool {

    let output_count = output_count();
    let redemption_predicate = predicate_address().unwrap();

    if (output_count == 7) {
        // REDEMPTION FLOW
        // 0th output is of type Change - (VRF)
        // 1st output is of type Change - (WINNING_ASSET)
        // 2nd output is of type Change - (USDT)
        // 3rd output is of type Coin - (WINNING_ASSET)
        // 4th output is of type Coin - (USDT)
        // 5th output is of type Coin - (USDT) - To ORACLE as Commission
        // 6th output is of type Change - (ETH / BASE_ASSET)
    
        // The checks on output_to are : 
        // USDT Change (Output 2) must go to redemption predicate
        // Winning Asset Coin (Output 3) must go to redemption predicate
        // USDT Coin (Output 4) == WINNING_ASSET - COMMISSION / 100 * WINNING_ASSET (Output 3)
        // USDT Coin (Output 5) must go to ORACLE
        // USDT Coin (Output 5) == COMMISSION / 100 * WINNING_ASSET (Output 3)

        let redemption_predicate = predicate_address().unwrap();

        let wining_amount = output_amount(3).unwrap();
        let commission_amount = (COMMISSION_PERCENTAGE * wining_amount / 100);
        let winning_amount_after_commission = wining_amount - commission_amount;

        return 
        // OUTPUT VALIDATIONS
        validate_output(0, VRF, 2) 
        && validate_output(1, WINNING_ASSET, 2) && validate_output(2, USDT, 2)
        && validate_output(3, WINNING_ASSET, 0) && validate_output(4, USDT, 0) 
        && validate_output(5, USDT, 0)
        && validate_output(6, BASE_ASSET, 2) 
        // OUTPUT TO VALIDATIONS
        && validate_output_to(2,redemption_predicate,2) && validate_output_to(3,redemption_predicate,0)
        && validate_output_to(5,ORACLE,0)
        // AMOUNT VALIDATIONS
        && output_amount(4).unwrap() == winning_amount_after_commission
        && output_amount(5).unwrap() == commission_amount;
    }
    else if (output_count == 9) {
        
        // CANCELATION ALONG WITH REDEMPTION FLOW

        // 0th output is of type Change - (VRF)
        // 1st output is of type Change - (YES)
        // 2nd output is of type Change - (NO)
        // 3rd output is of type Change - (USDT)
        // 4th output is of type Coin - (YES)
        // 5th output is of type Coin - (NO)
        // 6th output is of type Coin - (USDT)
        // 7th output is of type Coin - (USDT) - To ORACLE as Commission
        // 8th output is of type Change - (ETH / BASE_ASSET)
    
        // The checks on output_to are : 
        // USDT Change (Output 3) must go to redemption predicate
        // YES Coin (Output 4) must go to redemption predicate
        // NO Coin (Output 5) must go to redemption predicate
        // USDT Coin (Output 7) must go to redemption predicate
        // USDT Coint (Output 7) = COMMISSION / 100 * AMOUNT_MATCHED
        
        
        // COMMISSION = COMMISSION_PERCENTAGE * WINNING_ASSET - COMMISSION_PERCENTAGE * LOSING_ASSET

        // Y : 15   N : 5 (Yes Won)
        // Old Case : COMMISSION = 15 * 2 / 100 = 0.3
        // New Case : COMMISSION = 15 * 2 / 100 - 5 * 2 / 100 = .3 - .1 = .2

        // Y : 15   N : 5 (NO Won)
        // Old Case : COMMISSION = 5 * 2 / 100 = 0.1
        // New Case : COMMISSION = 5 * 2 / 100 - 15 * 2 / 100 = .1 - .3 = -.2 (we mark 0)

        // Y : 5   N : 5
        // Old Case : COMMISSION = 5 * 2 / 100 = 0.1
        // New Case : COMMISSION = 5 * 2 / 100 - 5 * 2 / 100 = .1 - .1 = 0

        // Y : 5   N : 15 (NO Won)
        // Old Case : COMMISSION = 15 * 2 / 100 = 0.3
        // New Case : COMMISSION = 15 * 2 / 100 - 5 * 2 / 100 = .3 - .1 = .2

        // Y : 5   N : 15 (YES Won)
        // Old Case : COMMISSION = 5 * 2 / 100 = 0.1
        // New Case : COMMISSION = 5 * 2 / 100 - 15 * 2 / 100 = .1 - .3 = -.2 (we mark 0)
        let amount_yes = output_amount(4).unwrap();
        let amount_no = output_amount(5).unwrap();
        let mut commission = 0;
        let mut winning_amount = 0;
        if (WINNING_ASSET == YES) {
            if (amount_yes > amount_no) {
                commission = (amount_yes - amount_no) * COMMISSION_PERCENTAGE / 100; 
            }
            winning_amount = amount_yes - commission;
        } else if (WINNING_ASSET == NO) {
            if (amount_no > amount_yes) {
                commission = (amount_no - amount_yes) * COMMISSION_PERCENTAGE / 100;
            }
            winning_amount = amount_no - commission;
        }

        return 
        // OUTPUT VALIDATIONS
        validate_output(0, VRF, 2) 
        && validate_output(1, YES, 2) && validate_output(2, NO, 2)
        && validate_output(3, USDT, 2) && validate_output(4, YES, 0) 
        && validate_output(5, NO, 0) 
        && validate_output(6, USDT, 0) && validate_output(7, USDT, 0) 
        && validate_output(8, BASE_ASSET, 2)
        // OUTPUT TO VALIDATIONS
        && validate_output_to(3,redemption_predicate,2)
        && validate_output_to(4,redemption_predicate,0) && validate_output_to(5,redemption_predicate,0)
        && validate_output_to(7,ORACLE,0)
        // AMOUNT VALIDATIONS
        && output_amount(6).unwrap() == winning_amount
        && output_amount(7).unwrap() == commission;

    }
    return false;
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