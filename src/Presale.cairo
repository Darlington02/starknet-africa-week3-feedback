%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import (Uint256, uint256_add, uint256_sub, uint256_unsigned_div_rem, uint256_signed_nn_le)
from starkware.starknet.common.syscalls import (get_caller_address, get_contract_address)
from src.interfaces.IERC20 import IERC20

// 
// CONSTANTS
// 
const ETH_CONTRACT = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7;
const REGPRICE = 1000000000000000;

// 
// STORAGE VARIABLE
// 
@storage_var
func token_address() -> (address: felt) {
}

@storage_var
func admin_address() -> (address: felt) {
}

@storage_var
func registered_address(address: felt) -> (status: felt) {
}

@storage_var
func claimed_address(address: felt) -> (status: felt) {
}

// 
// CONSTRUCTOR
// 
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenAddress: felt, adminAddress: felt
) {
    admin_address.write(adminAddress);
    token_address.write(tokenAddress);

    return ();
}

// EXTERNALS
@external
func register{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (this_contract) = get_contract_address();
    let (caller) = get_caller_address();
    let (token) = token_address.read();
    let regprice_in_uint = Uint256(REGPRICE, 0);

    // check that user is not already registered
    with_attr error_message("ICO: You have already registered!"){
        let (registration_status) = registered_address.read(caller);
        assert registration_status = 0;
    }

    // check that the user has beforehand approved the address of the ICO contract to spend the registration amount from his ETH balance
    with_attr error_message("ICO: You need to approve at least 0.001 ETH for registration!"){
        let (approved) = IERC20.allowance(ETH_CONTRACT, caller, this_contract);
        let (less_than) = uint256_signed_nn_le(regprice_in_uint, approved);
        assert less_than = 1;
    }

    // Transfer the registration price from the caller to the ICO contract address
    IERC20.transferFrom(ETH_CONTRACT, caller, this_contract, regprice_in_uint);

    // add the caller to the list of registered addresses
    registered_address.write(caller, 1);
    return ();
}

@external
func claim{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) {
    let (is_registered) = registered_address.read(address);

    // check that the caller is registered
    with_attr error_message("ICO: You are not eligible for this ICO"){
        assert is_registered = 1;
    }

    // check that caller has not already claimed
    with_attr error_message("ICO: You have already claimed your tokens!"){
        let (claim_status) = claimed_address.read(address);
        assert claim_status = 0;
    }

    // transfer the claim amount to the user
    let claim_amount = Uint256(20, 0);
    let (this_contract) = get_contract_address();
    let (token) = token_address.read();
    let (admin) = admin_address.read();
    IERC20.transferFrom(token, admin, address, claim_amount);
    
    // add the caller to the list of claimed address to prevent re-claiming
    claimed_address.write(address, 1);
    return ();
}

@view
func is_registered{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (status: felt) {
    let (is_registered) = registered_address.read(address);
    return (status=is_registered);
}
