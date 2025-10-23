// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BaseGamePass.sol";

contract BaseGame is ERC1155, Ownable {
    BaseGamePass public baseGamePass;
    uint256 public constant SESSION_DURATION = 15 minutes;
    uint256 public constant TOKEN_PER_USER = 10;
    uint256 public constant ENTRY_FEE = 0.01 ether;
    uint256 public constant FEE_PERCENTAGE = 2;
    uint256 public constant MAX_SESSIONS_PER_DAY = 3;
    uint256 public constant FINAL_TOKENS = 2;
    uint256 public sessionId;
    uint256 public sessionStartTime;
    uint256 public totalTokens;
    uint256 public tokensBurned;
    uint256 public dayStartTime;

    mapping(uint256 => mapping(address => bool)) public hasInteracted;
    mapping(uint256 => uint256) public tokenSupply;
    mapping(address => uint256) public userTokens;
    mapping(address => uint256) public sessionsPlayedToday;
    mapping(uint256 => address) public tokenOwners;
    uint256 public rewardPool;

    event SessionStarted(uint256 sessionId, uint256 startTime);
    event TokenBurned(uint256 tokenId);
    event RewardDistributed(address winner, uint256 amount);
    event TokenPurchased(address buyer, uint256 tokenId, uint256 amount);
    event PassMinted(address to, uint256 tokenId);

    constructor(address _passContract) ERC1155("https://your-ipfs-url.com/game-token/{id}.json") Ownable(msg.sender) {
        baseGamePass = BaseGamePass(_passContract);
        sessionId = 0;
        tokensBurned = 0;
        dayStartTime = block.timestamp;
    }

    function resetDailyLimit() internal {
        if (block.timestamp >= dayStartTime + 1 days) {
            dayStartTime = block.timestamp;
        }
    }

    function startSession() external onlyOwner {
        require(block.timestamp >= sessionStartTime + SESSION_DURATION, "Previous session still active");
        sessionId++;
        sessionStartTime = block.timestamp;
        totalTokens = 0;
        tokensBurned = 0;
        rewardPool = 0;
        emit SessionStarted(sessionId, sessionStartTime);
    }

    function joinSession() external payable {
        resetDailyLimit();
        require(baseGamePass.balanceOf(msg.sender) > 0, "BaseGame Pass required");
        require(msg.value == ENTRY_FEE, "Incorrect entry fee");
        require(block.timestamp < sessionStartTime + SESSION_DURATION, "Session ended");
        require(sessionsPlayedToday[msg.sender] < MAX_SESSIONS_PER_DAY, "Daily session limit reached");

        userTokens[msg.sender] += TOKEN_PER_USER;
        totalTokens += TOKEN_PER_USER;
        _mint(msg.sender, sessionId, TOKEN_PER_USER, "");
        tokenOwners[sessionId] = msg.sender;
        rewardPool += msg.value;
        sessionsPlayedToday[msg.sender]++;

        if (baseGamePass.totalSupply() < 6666) {
            baseGamePass.mintPass(msg.sender);
            emit PassMinted(msg.sender, baseGamePass.totalSupply());
        }
    }

    function tradeToken(address buyer, uint256 tokenId, uint256 amount, uint256 price) external payable {
        require(baseGamePass.balanceOf(buyer) > 0, "BaseGame Pass required");
        require(block.timestamp < sessionStartTime + SESSION_DURATION, "Session ended");
        require(msg.value >= price, "Insufficient payment");
        require(tokenSupply[tokenId] > 0, "Token burned");
        require(!hasInteracted[tokenId][buyer], "Already interacted with this token");

        hasInteracted[tokenId][buyer] = true;
        uint256 fee = (price * FEE_PERCENTAGE) / 100;
        rewardPool += fee;
        payable(msg.sender).transfer(price - fee);
        _safeTransferFrom(msg.sender, buyer, tokenId, amount, "");
        tokenOwners[tokenId] = buyer;
    }

    function burnToken(uint256 tokenId) external onlyOwner {
        require(block.timestamp < sessionStartTime + SESSION_DURATION, "Session ended");
        require(tokenSupply[tokenId] > 0, "Token already burned");
        require(totalTokens - tokensBurned > FINAL_TOKENS, "Cannot burn, final tokens reached");
        tokenSupply[tokenId] = 0;
        tokensBurned++;
        emit TokenBurned(tokenId);
    }

    function buyFromPlatform(uint256 tokenId, uint256 amount) external payable {
        require(baseGamePass.balanceOf(msg.sender) > 0, "BaseGame Pass required");
        require(tokenSupply[tokenId] > 0, "Token burned");
        require(msg.value >= amount * 0.005 ether, "Insufficient payment");
        _mint(msg.sender, tokenId, amount, "");
        tokenOwners[tokenId] = msg.sender;
        rewardPool += msg.value;
        emit TokenPurchased(msg.sender, tokenId, amount);
    }

    function endSession(uint256[] calldata finalTokenIds) external onlyOwner {
        require(block.timestamp >= sessionStartTime + SESSION_DURATION, "Session still active");
        require(finalTokenIds.length == FINAL_TOKENS, "Must provide 2 token IDs");
        require(tokenSupply[finalTokenIds[0]] > 0 && tokenSupply[finalTokenIds[1]] > 0, "Token burned");

        address winner1 = tokenOwners[finalTokenIds[0]];
        address winner2 = tokenOwners[finalTokenIds[1]];
        uint256 reward = (rewardPool * 80) / 100;
        uint256 halfReward = reward / 2;
        rewardPool = rewardPool - reward;
        payable(winner1).transfer(halfReward);
        payable(winner2).transfer(halfReward);
        emit RewardDistributed(winner1, halfReward);
        emit RewardDistributed(winner2, halfReward);

        _safeTransferFrom(winner1, owner(), finalTokenIds[0], tokenSupply[finalTokenIds[0]], "");
        _safeTransferFrom(winner2, owner(), finalTokenIds[1], tokenSupply[finalTokenIds[1]], "");
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}