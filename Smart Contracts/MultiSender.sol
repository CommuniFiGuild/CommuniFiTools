// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


//    ______                                      _ _______
//   / ____/___  ____ ___  ____ ___  __  ______  (_) ____(_)
//  / /   / __ \/ __ '__ \/ __ '__ \/ / / / __ \/ / /_  / /
// / /___/ /_/ / / / / / / / / / / / /_/ / / / / / __/ / /
// \____/\____/_/ /_/ /_/ / /_/ /_/\____/_/ /_/_/_/   /_/


interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint indexed amount);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint indexed amount);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint amount) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint value) external returns (bool);
}

contract MultiSender {
    /**
     * @dev Emitted when `value` tokens having address `token` are sent to
     * `to` account.
     *
     * Note that `value` may be zero.
     */
    event SendToken(address token, address to, uint value);

    /**
     * @dev Emitted when `value` PLS is sent from contract to
     * `to` account.
     *
     * Note that `value` will always be greater than zero.
     */
    event Refund(address indexed receiver, uint value);

    /**
     * @dev Emitted when `value` PLS are sent from (`from`) address
     * to contract.
     *
     * Note that `value` may be zero.
     */
    event Receive(address indexed from, uint value);

    mapping(address => uint) private balance;

    /**
    * @dev Transfers tokens from the sender's wallet to multiple recipients.
    * @param tokenAddress The address of the ERC20 token contract.
    * @param to An array of recipient addresses.
    * @param amount An array of token amounts to send to each recipient.
    * @notice The caller must have approved the contract to spend tokens on its behalf.
    * @notice The contract must have sufficient balance to cover the total amount of tokens to be sent.
    */
    function multisendToken(
            address tokenAddress, 
            address[] calldata to, 
            uint[] calldata amount
        ) external {

        assert(to.length == amount.length);

        IERC20 token = IERC20(tokenAddress);
        uint tokensApprovedToSpend = token.allowance(msg.sender, address(this));
        uint tokensPresentInWallet = token.balanceOf(msg.sender);
        uint numAddresses = to.length;

        uint tokensToSpend;
        for(uint i= 0; i < numAddresses; i++) {
            tokensToSpend += amount[i];
        }

        require(tokensPresentInWallet >= tokensToSpend, "Not enough tokens in wallet");
        require(tokensApprovedToSpend >= tokensToSpend, "approved for less tokens");


        for(uint i= 0; i < numAddresses; i++) {
            _transfer(tokenAddress, to[i], amount[i]);
        }

    }

    /**
    * @dev Transfers a specified amount of tokens from the sender's wallet to multiple recipients.
    * @param tokenAddress The address of the ERC20 token contract.
    * @param to An array of recipient addresses.
    * @param amount The amount of tokens to send to each recipient.
    * @notice The caller must have approved the contract to spend tokens on its behalf.
    * @notice The contract must have sufficient balance to cover the total amount of tokens to be sent.
    */
    function multisendToken(address tokenAddress, address[] calldata to, uint amount) external {

        IERC20 token = IERC20(tokenAddress);
        uint tokensApprovedToSpend = token.allowance(msg.sender, address(this));
        uint tokensPresentInWallet = token.balanceOf(msg.sender);
        uint numAddresses = to.length;

        uint tokensToSpend = numAddresses * amount;

        require(tokensPresentInWallet >= tokensToSpend, "Not enough tokens in wallet");
        require(tokensApprovedToSpend >= tokensToSpend, "approved for less tokens");


        for(uint i= 0; i < numAddresses; i++) {
            _transfer(tokenAddress, to[i], amount);
        }
    }

    /**
    * @dev Transfers PLS tokens from the sender's balance in contract to multiple recipients.
    * @param to An array of recipient addresses.
    * @param amount An array of PLS amounts to send to each recipient.
    * @notice The sender must have sufficient PLS balance in the contract to cover the total amount to be sent.
    * @notice Each recipient must receive the specified amount of PLS.
    * @notice The function will revert if any transfer fails.
    */
    function multisendPLS( 
            address[] calldata to, 
            uint[] calldata amount
        ) external payable {

        assert(to.length == amount.length);

        uint tokensApprovedToSpend = balance[msg.sender]; // PLS sent by the sender to the contract
        uint numAddresses = to.length;

        uint tokensToSpend; // PLS to send
        for(uint i= 0; i < numAddresses; i++) {
            tokensToSpend += amount[i];
        }

        require(tokensApprovedToSpend >= tokensToSpend * 1e18, "approved for less tokens");

        uint bal;
        for(uint i= 0; i < numAddresses; i++) {
            bal = amount[i] * 1e18;
            balance[msg.sender] -= bal;
            (bool status, ) = payable(to[i]).call{value: bal}("");
            require(status, "call failed");
        }

    }

    /**
    * @dev Transfers PLS tokens from the sender's balance in contract to multiple recipients.
    * @param to An array of recipient addresses.
    * @param amount PLS amounts to send to each recipient.
    * @notice The sender must have sufficient PLS balance in the contract to cover the total amount to be sent.
    * @notice Each recipient must receive the specified amount of PLS.
    * @notice The function will revert if any transfer fails.
    */
    function multisendPLS(
            address[] calldata to, 
            uint amount
        ) external {
        
        uint tokensApprovedToSpend = balance[msg.sender]; // PLS sent by the sender to the contract
        uint numAddresses = to.length;

        amount = amount * 1e18;
        uint tokensToSpend = numAddresses * amount;

        require(tokensApprovedToSpend >= tokensToSpend, "approved for less tokens");

        for(uint i= 0; i < numAddresses; i++) {
            balance[msg.sender] -= amount;
            (bool status, ) = payable(to[i]).call{value: amount}("");
            require(status, "call failed");
        }

    }

    // transfer ERC20 token from sender address to receivers
    function _transfer(address tokenAddress, address to, uint amount) internal {
        IERC20(tokenAddress).transferFrom(msg.sender, to, amount);
        emit SendToken(tokenAddress, to, amount);
    }


    /**
    * @dev Receive PLS and update the sender's balance.
    * @notice This function is automatically called when PLS is sent to the contract.
    * @notice The sender's balance will be increased by the amount of PLS sent.
    */
    receive() external payable { 
        balance[msg.sender] += msg.value;

        emit Receive(msg.sender, msg.value);
    }


    /**
    * @dev Refund PLS tokens to the sender .
    * @notice This function refunds the sender by sending PLS equal to their PLS balance in the contract.
    * @notice The sender's PLS balance will be set to 0 after the refund.
    * @notice The function will revert if the refund fails.
    */
    function refund() external payable {
        require(balance[msg.sender] > 0, "0 PLS balance");
        uint bal = balance[msg.sender];
        balance[msg.sender] = 0;
        (bool status, ) = payable(msg.sender).call{value: bal}("");
        require(status, "call failed");

        emit Refund(msg.sender, bal);
    }
}
