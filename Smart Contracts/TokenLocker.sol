// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

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

contract TokenLocker {
    /**
     * @dev Emitted when PLS is sent.
     * @param value The amount of PLS sent.
     */
    event SendPLS(uint value);
    /**
     * @dev Emitted when a token is sent.
     * @param token The address of the token contract.
     * @param value The amount of tokens sent.
     */
    event SendToken(address indexed token, uint value);
    /**
     * @dev Emitted when PLS is received.
     * @param value The amount of PLS received.
     */
    event ReceivePLS(uint value);
    /**
     * @dev Emitted when a token is received.
     * @param token The address of the token contract.
     * @param value The amount of tokens received.
     */
    event ReceiveToken(address indexed token, uint value);

    struct Lock {
        uint lockStartTime;
        uint lockEndTime;
        bool isPls;
        address tokenAddress;
        uint value;
        bool status;
    }

    address public immutable owner;
    uint internal lockId;
    mapping (uint => Lock) public locks;

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Creates a lock for a specific token.
     * @param _tokenAddress The address of the token contract.
     * @param _value The amount of tokens to lock.
     * @param duration The duration of the lock in seconds.
     * Requirements:
     * - Only the contract owner can call this function.
     */
    function createTokenLock(
        address _tokenAddress, 
        uint _value,
        uint duration
        ) external {
            require(msg.sender == owner, "not owner");
            
            IERC20 token = IERC20(_tokenAddress);
            require(token.allowance(owner, address(this)) >= _value, "allowance for less tokens");
            token.transferFrom(msg.sender, address(this), _value);
            lockId += 1;
            Lock memory lock;
            lock.lockStartTime = block.timestamp;
            lock.lockEndTime = block.timestamp + duration;
            lock.tokenAddress = _tokenAddress;
            lock.value = _value;
            lock.status = true;

            locks[lockId] = lock;
            emit ReceiveToken(_tokenAddress, _value);
    }

    /**
     * @dev Creates a lock for PLS (native gas token for PulseChain).
     * @param duration The duration of the lock in seconds.
     * Requirements:
     * - Only the contract owner can call this function.
     */
    function createPlsLock(
        uint duration
    ) external payable {
        require(msg.sender == owner, "not owner");
        lockId += 1;

        Lock memory lock;
        lock.lockStartTime = block.timestamp;
        lock.lockEndTime = block.timestamp + duration;
        lock.isPls = true;
        lock.value = msg.value;
        lock.status = true;

        locks[lockId] = lock;
        emit ReceivePLS(msg.value);
    }

    /**
     * @dev Ends a lock and withdraws the locked tokens or PLS.
     * @param _lockId The ID of the lock to end.
     * Requirements:
     * - The lock must exist, not have been withdrawn already, and its end time must have passed.
     */
    function endLockAndWithdraw(uint _lockId) external {
        Lock storage lock = locks[_lockId];
        require(lock.lockStartTime != 0, "invalid lock id");
        require(lock.status, "already withdrawn");
        require(lock.lockEndTime > block.timestamp, "cannot end lock: time left");
        if (lock.isPls) {
            uint value = lock.value;
            lock.value = 0;
            (bool success, ) = payable(owner).call{value: value}("");
            require(success, "call failed");
            lock.status = false;
            SendPLS(value);
            
        } else {
            IERC20 token = IERC20(lock.tokenAddress);
            uint val = lock.value;
            lock.value = 0;
            token.transfer(owner, val);
            lock.status =  false;
            SendToken(lock.tokenAddress, val);
        }
    }
}