// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/token/ERC721/ERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v5.0.2/contracts/access/Ownable.sol";

contract BaseGamePass is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    uint256 public constant MAX_SUPPLY = 6666;

    constructor() ERC721("BaseGamePass", "BGP") Ownable(msg.sender) {
        _tokenIdCounter = 0;
    }

    function mintPass(address to) external onlyOwner {
        require(_tokenIdCounter < MAX_SUPPLY, "Max NFT supply reached");
        _tokenIdCounter++;
        _safeMint(to, _tokenIdCounter);
    }

    function transferPass(address from, address to, uint256 tokenId) external {
        _safeTransfer(from, to, tokenId, "");
    }

    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        return string(abi.encodePacked("https://your-ipfs-url.com/nft/", tokenId, ".json"));
    }
}
