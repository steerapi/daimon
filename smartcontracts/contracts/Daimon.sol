pragma solidity ^0.5.2;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";
import "./ProblemToken.sol";

contract Daimon {
    using SafeMath for uint256;
    using SafeERC20 for ProblemToken;
    
    uint256[] private _currentDistances;
    uint256[] private _currentScores;    
    bytes32 private _currentModelDigest;

    ProblemToken private _token;
    uint256 private _createdAt;
    uint256 private _startTime;
    uint256 private _nextBlockTime;
    uint256 private _blockTime;
    uint256 private _multiplier;

    struct ProblemBlock {
        address submitter;
        bool submitted;
    }
    bytes32[] private _problemBlocks;
    mapping (bytes32 => ProblemBlock) _problemBlocksMap;

    struct Validation {
        address[] validators;
        mapping (address => bool) validatorsMap;
        uint256[] distances;
        // Must agree on how to score the distance. This will effect how the reward is given out.
        uint256[] scores;
    }
    struct ImprovementBlock {
        address submitter;
        mapping (bytes32 => Validation) validation;
        bytes32[] distancesDigests;
        mapping (bytes32 => bool) distancesDigestsMap;
    }

    mapping (bytes32 => ImprovementBlock) private _models;

    bytes32[] private _modelDigests;
    uint256 private _max;
    bytes32 private _maxModelDigest;
    bytes32 private _maxDistancesDigest;
    uint256[] private _maxDistances;
    uint256[] private _maxScores;
    
    constructor (
        string memory name, 
        string memory symbol, 
        uint8 decimals,
        uint256 problemDefinitionPeriodInSeconds,
        uint256 blockTimeInSeconds
    ) public {
        _token = new ProblemToken(name, symbol, decimals);
        _createdAt = block.timestamp;
        _startTime = _createdAt + problemDefinitionPeriodInSeconds;
        _blockTime = blockTimeInSeconds;
        _nextBlockTime = _startTime; // require commit before voting begins + _blockTime;
        _multiplier = _token.multiplier();
        emit DaimonCreated(name, symbol, decimals, problemDefinitionPeriodInSeconds, blockTimeInSeconds, _startTime);
    }

    // submit test set    
    function submitTestSet(
        bytes32 testDigest
    ) public {
        require(block.timestamp < _startTime, 'period for submitting test set has ended'); 
        if(_problemBlocksMap[testDigest].submitted != true){
            _problemBlocksMap[testDigest].submitter = msg.sender;
            _problemBlocksMap[testDigest].submitted = true;
            _currentDistances.push(_multiplier);
            _currentScores.push(0);
            _maxDistances.push(_multiplier);
            _maxScores.push(0);
            _problemBlocks.push(testDigest);
            emit TestSetSubmitted(msg.sender, testDigest, _problemBlocks.length-1, _startTime);
        }
    }

    // submit model
    function submitModel(
        bytes32 modelDigest
    ) public {
        require(block.timestamp >= _startTime, 'voting period has not started yet.');
        require(block.timestamp < _nextBlockTime, 'voting period has ended, please commit this block first.');
        _models[modelDigest].submitter = msg.sender;
        _modelDigests.push(modelDigest);
        emit ModelSubmitted(msg.sender, modelDigest, _modelDigests.length-1, _nextBlockTime);
    }
    
    function _toBytes(uint256 x) internal view returns (bytes memory b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    function _digestDistancesScores(uint256[] memory distances, uint256[] memory scores) internal view returns (bytes32 digest) {
        bytes memory distancesBytes = new bytes(2*32*distances.length);
        uint byteLength = 0;
        for (uint i = 0; i < distances.length; i++) {
            bytes memory byteString = _toBytes(distances[i]);
            for (uint j = 0; j < 32; j++) {
                distancesBytes[byteLength] = byteString[j];
                byteLength += 1;
            }
        }
        for (uint i = 0; i < scores.length; i++) {
            bytes memory byteString = _toBytes(scores[i]);
            for (uint j = 0; j < 32; j++) {
                distancesBytes[byteLength] = byteString[j];
                byteLength += 1;
            }
        }
        digest = keccak256(distancesBytes);
    }

    function vote(
        bytes32 modelDigest,
        uint256[] memory distances,
        uint256[] memory scores
    ) public {
        require(block.timestamp >= _startTime, 'voting period has not started yet.');
        require(block.timestamp < _nextBlockTime, 'voting period has ended, please commit this period first');
        require(distances.length == _problemBlocks.length, 'distances length must be equal to the problems length');
        for (uint i = 0; i < _problemBlocks.length; i++) {
            require(distances[i] < _currentDistances[i], 'all distances must be less than all current distances');  
        }
        bytes32 distancesDigest = _digestDistancesScores(distances, scores);
        // check if this validator already vote for this modelDigest 
        
        if(_models[modelDigest].validation[distancesDigest].validatorsMap[msg.sender] != true){
            emit BlockVoted(msg.sender, modelDigest, distancesDigest, distances, scores, _nextBlockTime);

            _models[modelDigest].validation[distancesDigest].validatorsMap[msg.sender] = true;
            _models[modelDigest].validation[distancesDigest].validators.push(msg.sender);
            _models[modelDigest].validation[distancesDigest].distances = distances;
            _models[modelDigest].validation[distancesDigest].scores = scores;
            // check if this modelDigest already in the set of distancesDigests
            if(_models[modelDigest].distancesDigestsMap[distancesDigest] != true){
                _models[modelDigest].distancesDigestsMap[distancesDigest] = true;
                _models[modelDigest].distancesDigests.push(distancesDigest);
            }
            // update the winning vote.
            uint256 newMax = _models[modelDigest].validation[distancesDigest].validators.length;
            if(newMax > _max){
                _maxModelDigest = modelDigest;
                _maxDistancesDigest = distancesDigest;
                for (uint i = 0; i < _problemBlocks.length; i++) {
                  _maxDistances[i] = distances[i];
                  _maxScores[i] = scores[i];
                }

                emit NewLeadingBlock(_maxModelDigest, _maxDistancesDigest, _maxDistances, _maxScores, _nextBlockTime);
            }
        }

    }

    // distance must be multiplied by _token.multiplier() already
    function _reward(uint256 winningScore, uint256 currentScore) internal view returns (uint256) {
        return (winningScore-currentScore);
    }

    function _rewardScaling(uint256 amount, uint256 position) internal view returns (uint256) {
        // half each position starting from 1
        return amount/((2)**(position+1));
    }

    function _moveBlock() internal {
        // move to next block
        delete _max;
        delete _maxModelDigest;
        delete _maxDistancesDigest;
        for (uint i = 0; i < _problemBlocks.length; i++) {
          if(i < _maxDistances.length){
            delete _maxDistances[i];
          }
          if(i < _maxScores.length){
            delete _maxScores[i];
          }
          // delete _modelDigests;
        }
        _nextBlockTime = block.timestamp + _blockTime;

        emit BlockCommitted(_currentModelDigest, _currentDistances, _nextBlockTime);
    }

    function commit() public {
        require(block.timestamp >= _nextBlockTime, 'voting period has not ended');
        
        if(_maxModelDigest == 0){
          // no vote, move to next block
          _moveBlock();
          return;
        }

        // reward
        uint256 amount = 0;
        for (uint i = 0; i < _problemBlocks.length; i++) {
            amount += _reward(_maxScores[i], _currentScores[i]);
        }
        amount = amount/_problemBlocks.length;
        
        _token.mint(_models[_maxModelDigest].submitter, amount);        
        for (uint j = 0; j < _models[_maxModelDigest].validation[_maxDistancesDigest].validators.length; j++) {
            address validator = _models[_maxModelDigest].validation[_maxDistancesDigest].validators[j];
            uint256 valAmount = _rewardScaling(amount, j);
            _token.mint(validator, valAmount);
        }

        // update current score
        for (uint i = 0; i < _problemBlocks.length; i++) {
          _currentDistances[i] = _maxDistances[i];
          _currentScores[i] = _maxScores[i];
        }
        _currentModelDigest = _maxModelDigest;

        _moveBlock();
    }

    // -- events --
    event DaimonCreated(
        string name, 
        string symbol, 
        uint8 decimals,
        uint256 problemDefinitionPeriodInSeconds,
        uint256 blockTimeInSeconds,
        uint256 startTime
    );
    event TestSetSubmitted(address submitter, bytes32 testSetDigest, uint256 position, uint256 endAt);
    event ModelSubmitted(address submitter, bytes32 modelDigest, uint256 position, uint256 endAt);
    event BlockVoted(address submitter, bytes32 modelDigest, bytes32 distancesDigest, uint256[] distances, uint256[] scores, uint256 endAt);
    event NewLeadingBlock(bytes32 modelDigest, bytes32 distancesDigest, uint256[] distances, uint256[] scores, uint256 endAt);
    event BlockCommitted(bytes32 currentModelDigest, uint256[] currentDistances, uint256 nextEndAt);
    event NewBlockTime(uint256 blockTime);

    // -- public setters --    
    // function setBlockTime(uint256 blockTime) public {
    //     _blockTime = blockTime;
    //     emit NewBlockTime(_blockTime);
    // }

    // -- public getters --
    function getTokenAddress() public view returns (address) {
        return address(_token);
    }
    function getNumberOfTestSets() public view returns (uint256) {
        return _problemBlocks.length;
    }
    function getCurrentScoreAt(uint256 i) public view returns (uint256) {
        return _currentScores[i];
    }
    function getCurrentDistanceAt(uint256 i) public view returns (uint256) {
        return _currentDistances[i];
    }
    function getCurrentModelDigest() public view returns (bytes32) {
        return _currentModelDigest;
    }
    function getStartTime() public view returns (uint256) {
        return _startTime;
    }
    function getNextBlockTime() public view returns (uint256) {
        return _nextBlockTime;
    }
    function getBlockTime() public view returns (uint256) {
        return _blockTime;
    }
    function getCreatedTime() public view returns (uint256) {
        return _createdAt;
    }
    function getCurrentTime() public view returns (uint256) {
        return block.timestamp;
    }
    function getTestSetDigestAt(uint256 i) public view returns (bytes32) {
        require(i < _problemBlocks.length);
        return _problemBlocks[i];
    }
    function getRewardScaling(uint256 amount, uint256 position) public returns (uint256) {        
        return _rewardScaling(amount, position);
    }
    function getDigestDistancesScores(uint256[] memory distances, uint256[] memory scores) public returns (bytes32 digest) {
        return _digestDistancesScores(distances, scores);
    }

    function getNumberOfModels() public view returns (uint256) {
        return _modelDigests.length;
    }
    function getModelDigestAt(uint256 i) public view returns (bytes32) {
        require(i < _modelDigests.length);
        return _modelDigests[i];
    }
    function multiplier() public view returns (uint256) {
        return _multiplier;
    }
}