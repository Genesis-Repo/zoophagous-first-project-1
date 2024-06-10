// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract NFTMarketplace is ERC721Enumerable, ReentrancyGuard {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    address public owner;
    uint256 public royaltyFee; // Royalty fee in percentage

    mapping(uint256 => uint256) private _tokenRoyalties; // Royalty fee for each token
    mapping(uint256 => address) private _tokenCreators; // Creator of each token
    EnumerableMap.UintToAddressMap private _tokenRoyaltyRecipients; // Royalty recipients for each token

    mapping(uint256 => address) private _tokenEscrow; // Escrow address for each token
    mapping(uint256 => uint256) private _tokenPrice; // Price set for each token

    event RoyaltySet(uint256 indexed tokenId, uint256 royaltyFee, address royaltyRecipient);
    event NFTSold(address buyer, uint256 tokenId, uint256 price);
    event EscrowSet(uint256 indexed tokenId, address escrow, uint256 price);

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
        owner = _msgSender();
        royaltyFee = 5; // 5% royalty fee by default
    }

    function setRoyalty(uint256 tokenId, uint256 royaltyFee, address royaltyRecipient) public {
        require(_exists(tokenId), "Token does not exist");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");

        _tokenRoyalties[tokenId] = royaltyFee;
        _tokenRoyaltyRecipients.set(tokenId, royaltyRecipient);

        emit RoyaltySet(tokenId, royaltyFee, royaltyRecipient);
    }

    function setTokenPrice(uint256 tokenId, uint256 price) public {
        require(_exists(tokenId), "Token does not exist");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");

        _tokenPrice[tokenId] = price;

        emit EscrowSet(tokenId, address(0), price); // Reset escrow if price is updated
    }

    function setEscrow(uint256 tokenId, address escrow) public {
        require(_exists(tokenId), "Token does not exist");
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");
        require(_tokenPrice[tokenId] > 0, "Token price is not set");

        _tokenEscrow[tokenId] = escrow;

        emit EscrowSet(tokenId, escrow, _tokenPrice[tokenId]);
    }

    function buyNFT(uint256 tokenId) public payable nonReentrant {
        require(_exists(tokenId), "Token does not exist");
        address tokenOwner = ownerOf(tokenId);
        require(tokenOwner != address(0), "Invalid token owner");

        require(msg.value >= _tokenPrice[tokenId], "Insufficient funds");

        uint256 price = msg.value;
        uint256 tokenRoyalty = (price * _tokenRoyalties[tokenId]) / 100;
        uint256 amountAfterRoyalty = price - tokenRoyalty;

        if (_tokenEscrow[tokenId] != address(0)) {
            require(msg.sender == _tokenEscrow[tokenId], "Only the designated escrow can release funds");
        }

        payable(tokenOwner).transfer(amountAfterRoyalty); // Send payment to token owner
        payable(_tokenRoyaltyRecipients.get(tokenId)).transfer(tokenRoyalty); // Send royalty fee to recipient

        _transfer(tokenOwner, msg.sender, tokenId); // Transfer ownership of token

        emit NFTSold(msg.sender, tokenId, price);
    }

    function setRoyaltyFee(uint256 newRoyaltyFee) public {
        require(_msgSender() == owner, "Caller is not the owner");
        royaltyFee = newRoyaltyFee;
    }
}