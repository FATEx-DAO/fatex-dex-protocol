// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";


contract MerkleDistributor {
    using SafeERC20 for IERC20;

    event Claimed(uint256 index, address account, uint256 amount);

    address public immutable token;
    bytes32 public immutable merkleRoot;
    uint256 public immutable startTimestamp;
    uint256 public immutable vestingDuration;

    // This is a packed array of booleans.
    mapping(address => uint256) private claimedMap;

    constructor(
        address _token,
        bytes32 _merkleRoot,
        uint _startTimestamp,
        uint256 _vestingDuration
    ) public {
        token = _token;
        merkleRoot = _merkleRoot;
        startTimestamp = _startTimestamp;
        vestingDuration = _vestingDuration;
    }

    function getClaimed(address _account) public view returns (uint256) {
        return claimedMap[_account];
    }

    function _setClaimed(address _account, uint256 _amount) private {
        claimedMap[_account] += _amount;
    }

    function claim(
        uint256 _index,
        address _account,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) external {
        uint claimed = getClaimed(_account);
        require(claimed < _amount, 'MerkleDistributor: Drop already claimed');

        // Verify the merkle proof
        bytes32 node = keccak256(abi.encodePacked(_index, _account, _amount));
        require(MerkleProof.verify(_merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof');

        // The subtraction
        uint durationPassed = block.timestamp - startTimestamp;
        if (durationPassed >= vestingDuration) {
            // allow the user to get whatever hasn't been claimed
            _amount -= claimed;
        } else {
            // scale the user's claim amount to the % vesting
            // we are protected by vestingDuration == 0, since the `if` statement would fire if vestingDuration == 0;
            _amount = (_amount * durationPassed / vestingDuration) - claimed;
        }

        // Mark it claimed and send the token
        _setClaimed(_account, _amount);
        IERC20(token).safeTransfer(_account, _amount);
        emit Claimed(_index, _account, _amount);
    }
}
