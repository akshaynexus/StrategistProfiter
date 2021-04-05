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

contract StrategistProfiterBSCV2 is Ownable {

    using Address for address payable;
    using SafeERC20 for IERC20;
    using SafeERC20 for IVault;

    struct StrategyConf {
	    IStrategy Strat;
	    IVault vault;
	    IERC20 want;
	    IERC20 sellTo;
    }

    StrategyConf[] strategies;

    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant pancakeRouter = 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F;

    IWETH9 constant iWBNB = IWETH9(WBNB);
    ISharer sharer = ISharer(0x8FE82eadD954F356375B4579e108B2bF70DaCeb5);

    event Cloned(address payable newDeploy);
    event AddedStrategy(address indexed strategy, address want, address sellTo);
    event RemovedStrategy(address indexed strategy, address want, address sellTo);
    event SwappedTokens(uint256 wbnbOut);

    event NoTokensToSwap(address indexed strategy);

    receive() external payable {}

    address public internOwner;

    constructor() {
        internOwner = msg.sender;
    }

    modifier onlyCurrentOwner {
        if(owner() != address(0))
            require(msg.sender == owner(),"!owner");
        else if(internOwner != address(0))
            require(msg.sender == internOwner,"!internOwner");
        //If both are default allow call
        _;
    }

    function setInternOwner(address _newIntern) external onlyCurrentOwner {
        internOwner = _newIntern;
    }

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
        StrategistProfiterBSCV2(newProfiter).setInternOwner(msg.sender);
        emit Cloned(newProfiter);
    }

    function getStrategies() external view returns (StrategyConf[] memory) {
        return strategies;
    }

    function removeStrat(uint index) external onlyCurrentOwner {
        emit RemovedStrategy(address(strategies[index].Strat), address(strategies[index].want), address(strategies[index].sellTo));
        delete strategies[index];
        strategies.pop();
    }

    function getTokenOutPath(address _token_in,address _token_out ) internal pure returns (address [] memory path) {
        bool is_wbnb = _token_in == WBNB || _token_out == WBNB;
        path = new address[](is_wbnb ? 2 : 3);
        path[0] = _token_in;
        if (is_wbnb) {
            path[1] = _token_out;
        } else {
            path[1] = WBNB;
            path[2] = _token_out;
        }
    }

    function addStrat(address strategy, address sellTo) external onlyCurrentOwner {
        IStrategy _strat = IStrategy(strategy);
        IERC20 _want = IERC20(_strat.want());
        IVault _vault = IVault(_strat.vault());
	    strategies.push(
            StrategyConf(
                {
	                Strat: _strat,
	                vault: _vault,
	                want: _want,
	                sellTo: IERC20(sellTo)
                }
            )
        );
        emit AddedStrategy(strategy, address(_want), sellTo);
    }

    function claimandSwap() external onlyCurrentOwner {
        for(uint i=0;i<strategies.length;i++){
            //Call dist to get the vault tokens
            sharer.distribute(address(strategies[i].Strat));
            //Call transfer from msg.sender
            strategies[i].vault.safeTransferFrom(msg.sender, address(this), strategies[i].vault.balanceOf(msg.sender));
            if(strategies[i].vault.balanceOf(address(this)) > 0) {
                //Withdraw tokens to want
                strategies[i].vault.withdraw();
                sellToWETH(strategies[i].want,strategies[i].sellTo);
            }
            else {
                emit NoTokensToSwap(address(strategies[i].Strat));
            }
        }
        uint wbnbbal = iWBNB.balanceOf(address(this));
        if(wbnbbal > 0) iWBNB.withdraw(wbnbbal);
        msg.sender.sendValue(wbnbbal);
    }

    function sellToWETH(IERC20 _want,IERC20 _sellTo) internal {
        IUniswapRouter routerTouse = IUniswapRouter(pancakeRouter);
        uint sellAmount = _want.balanceOf(address(this));
        address[] memory swapPath = getTokenOutPath(address(_want),address(_sellTo));
        //First approve to spend want
        _want.safeApprove(address(routerTouse),sellAmount);
        //Swap to sellto via path
        uint256[] memory amountsOut = routerTouse.swapExactTokensForTokens(sellAmount, 0, swapPath, address(this), block.timestamp);
        emit SwappedTokens(amountsOut[amountsOut.length - 1]);
    }

    function retrieveETH() external onlyCurrentOwner {
        msg.sender.sendValue(address(this).balance);
    }

    function retreiveToken(address token) external onlyCurrentOwner {
        IERC20 iToken = IERC20(token);
        iToken.transfer(owner(),iToken.balanceOf(address(this)));
    }

    function updateSharer(address _newSharer) external onlyCurrentOwner {
        sharer = ISharer(_newSharer);
    }

}