// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/dao/Bounty.sol";

contract BountyTest is Test {
    BountyContract public bounty;
    uint256 mainnetFork;

    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant SHIB_ADDRESS = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;

    mapping(address => AggregatorV3Interface) public priceFeeds;

    function setUp() public returns(address) {
        try vm.createFork(vm.envString("ALCHEMY_MAINNET_RPC_URL")) returns (uint256 forkId) {
            mainnetFork = forkId;
        } catch {
            mainnetFork = vm.createFork(vm.envString("INFURA_MAINNET_RPC_URL"));
        }
        vm.selectFork(mainnetFork);

        InitialETHDataFeeds[] memory initialDataFeeds = new InitialETHDataFeeds[](4);
        initialDataFeeds[0] = InitialETHDataFeeds(WBTC_ADDRESS, 0xdeb288F737066589598e9214E782fa5A8eD689e8);
        initialDataFeeds[1] = InitialETHDataFeeds(SHIB_ADDRESS, 0x8dD1CD88F43aF196ae478e91b9F5E4Ac69A97C61);

        address sender = makeAddr("sender");

        vm.startPrank(sender);
        bounty = new BountyContract(initialDataFeeds, WETH_ADDRESS);
        vm.stopPrank();

        // set price feeds manually
        priceFeeds[WBTC_ADDRESS] = AggregatorV3Interface(0xdeb288F737066589598e9214E782fa5A8eD689e8);
        priceFeeds[SHIB_ADDRESS] = AggregatorV3Interface(0x8dD1CD88F43aF196ae478e91b9F5E4Ac69A97C61);

        return sender;
    }

    function testCreateBounty() public {
        address owner = setUp();

        uint256 wbtcValue = _value(WBTC_ADDRESS, 1); // 1 BTC
        uint256 shibValue = _value(SHIB_ADDRESS, 1); // 2400000000 SHIB
        uint256 shibInBtc = wbtcValue * 10 ** 8 / shibValue; // get shib amount in one BTC

        // create a bounty to get 1 BTC for 2400000000 SHIB
        vm.startPrank(owner);
        dealAndApprove(SHIB_ADDRESS, owner, shibInBtc); // deal SHIB amount - not required for this test, useful for fulfillment
        bounty.createBounty(WBTC_ADDRESS, SHIB_ADDRESS, shibInBtc); // 1 BTC equivalent to 2400000000 SHIB
        vm.stopPrank();

        Bounty memory b = bounty.getBounty(0);
        assertEq(b.amountGive, shibInBtc);
        assertEq(b.creator, owner);
        assertEq(b.tokenWant, WBTC_ADDRESS);
        assertEq(b.tokenGive, SHIB_ADDRESS);
        assertTrue(b.status == BountyStatus.ACTIVE);

    }

    function testFulfillBounty() public {
        testCreateBounty(); // create a bounty, also tests createBounty

        address fulfiller = makeAddr("fulfiller");

        uint256 fulfilmentAmountBTC =  10 ** ERC20(WBTC_ADDRESS).decimals();

        vm.startPrank(fulfiller);
        dealAndApprove(WBTC_ADDRESS, fulfiller, fulfilmentAmountBTC); // deal 1 btc
        bounty.fulfillBounty(0, fulfilmentAmountBTC); // fulfill the bounty, 1 BTC
        vm.stopPrank();

        Bounty memory b = bounty.getBounty(0);
        assertTrue(b.status == BountyStatus.FULFILLED);
    }

    function _value(address _token, uint256 _amount) internal view returns(uint256) {
        AggregatorV3Interface priceFeed = priceFeeds[_token];
        (, int price,,,) = priceFeed.latestRoundData();
        return uint256(price) * _amount;
    }

    function dealAndApprove(address token, address sender, uint256 amount) public {
        ERC20(token).approve(address(bounty), amount);
        deal(token, sender, amount);
    }
}