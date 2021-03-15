pragma solidity >=0.7.0 <0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/IUniswapRouter.sol';
import './interfaces/ISharer.sol';
import './interfaces/IStrategy.sol';
import './interfaces/IVault.sol';

interface IWETH9 is IERC20 {
    function withdraw(uint amount) external;
}

contract StrategistProfiter is Ownable {

    using Address for address payable;
    using SafeERC20 for IERC20;
    using SafeERC20 for IVault;

    struct StrategyConf {
	    IStrategy Strat;
	    IVault vault;
	    IERC20 want;
	    IERC20 sellTo;
	    bool sellViaSushi;
    }

    StrategyConf[] strategies;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant uniRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant sushiRouter = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;

    IWETH9 constant iWETH = IWETH9(WETH);
    ISharer constant sharer = ISharer(0x2C641e14AfEcb16b4Aa6601A40EE60c3cc792f7D);

    event Cloned(address payable newDeploy);

    receive() external payable {}

    function clone() external returns (address payable newProfiter) {
        // Copied from https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol
        bytes20 addressBytes = bytes20(address(this));

        assembly {
            // EIP-1167 bytecode
            let clone_code := mload(0x40)
            mstore(
                clone_code,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone_code, 0x14), addressBytes)
            mstore(
                add(clone_code, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            newProfiter := create(0, clone_code, 0x37)
        }

        StrategistProfiter(newProfiter).transferOwnership(
            msg.sender
        );

        emit Cloned(newProfiter);
    }

    function getStrategies() external view returns (StrategyConf[] memory) {
        return strategies;
    }

    function removeStrat(uint index) external onlyOwner {
        delete strategies[index];
    }

    function getTokenOutPath(address _token_in,address _token_out ) internal pure returns (address [] memory path) {
        bool is_weth = _token_in == WETH || _token_out == WETH;
        path = new address[](is_weth ? 2 : 3);
        path[0] = _token_in;
        if (is_weth) {
            path[1] = _token_out;
        } else {
            path[1] = WETH;
            path[2] = _token_out;
        }
    }

    function addStrat(address strategy, address sellTo, bool useSushiToSell) external onlyOwner {
        IStrategy _strat = IStrategy(strategy);
        IERC20 _want = IERC20(_strat.want());
        IVault _vault = IVault(_strat.vault());
	    strategies.push(
            StrategyConf(
                {
	                Strat: _strat,
	                vault: _vault,
	                want: _want,
	                sellTo: IERC20(sellTo),
	                sellViaSushi:useSushiToSell
                }
            )
        );
    }

    function claimandSwap() external onlyOwner {
        for(uint i=0;i<strategies.length;i++){
            //Call dist to get the vault tokens
            sharer.distribute(address(strategies[i].Strat));
            //Call transfer from msg.sender
            strategies[i].vault.safeTransferFrom(msg.sender, address(this), strategies[i].vault.balanceOf(msg.sender));
            //Withdraw tokens to want
            strategies[i].vault.withdraw();
            sellToWETH(strategies[i].want,strategies[i].sellTo,strategies[i].sellViaSushi);
        }
        uint wethbal = iWETH.balanceOf(address(this));
        if(wethbal > 0) iWETH.withdraw(wethbal);
        msg.sender.sendValue(wethbal);
    }

    function sellToWETH(IERC20 _want,IERC20 _sellTo,bool _useSushi) internal {
        IUniswapRouter routerTouse = _useSushi ? IUniswapRouter(sushiRouter)  :  IUniswapRouter(uniRouter);
        uint sellAmount = _want.balanceOf(address(this));
        //First approve to spend want
        _want.safeApprove(address(routerTouse),sellAmount);
        //Swap to sellto via path
        routerTouse.swapExactTokensForTokens(sellAmount, 0, getTokenOutPath(address(_want),address(_sellTo)), address(this), block.timestamp);
    }

    function retrieveETH() external onlyOwner {
        msg.sender.sendValue(address(this).balance);
    }

    function retreiveToken(address token) external onlyOwner {
        IERC20 iToken = IERC20(token);
        iToken.transfer(owner(),iToken.balanceOf(address(this)));
    }
}