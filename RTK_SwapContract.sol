pragma solidity ^0.6.2;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.1.0/contracts/token/ERC20/ERC20.sol";

contract RTK_SwapContract {
    
    address private owner;
    /*
    * Token_RTKL[0] = RTKL1 is actually original RTK
    * Token_RTKL[1...4] are RTKLX
    * Token_Bullet is addy of bullet contract
    */
    mapping(uint256 => address) private _Token_RTKL;
    mapping(uint256 => uint256) private _RTKLX_ExtCirculation;
    address private _Token_Bullet;
    
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    
    // modifier to check if caller is owner
    modifier OwnerOnly() {
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    /*
    * a0 = RTK
    * a1 = RTKL2
    * a2 = RTKL3
    * a3 = RTKL4
    * a4 = RTKL5
    */
    constructor(address a0, address a1, address a2, address a3, address a4, address bullet) public {
        owner = msg.sender;
        _Token_RTKL[0] = a0;
        _Token_RTKL[1] = a1;
        _Token_RTKL[2] = a2;
        _Token_RTKL[3] = a3;
        _Token_RTKL[4] = a4;
        _Token_Bullet = bullet;
        _RTKLX_ExtCirculation[0] = ERC20(a0).totalSupply();
        _RTKLX_ExtCirculation[1] = 0;
        _RTKLX_ExtCirculation[2] = 0;
        _RTKLX_ExtCirculation[3] = 0;
        _RTKLX_ExtCirculation[4] = 0;
        emit OwnerSet(address(0), owner);
    }

    function changeOwner(address newOwner) public OwnerOnly {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    function getOwner() external view returns (address) {
        return owner;
    }
    
    /*
    * a0 = RTK
    * a1 = RTKL2
    * a2 = RTKL3
    * a3 = RTKL4
    * a4 = RTKL5
    */
    function changeTokenAddresses(address a0, address a1, address a2, address a3, address a4, address bullet) public OwnerOnly {
        _Token_RTKL[0] = a0;
        _Token_RTKL[1] = a1;
        _Token_RTKL[2] = a2;
        _Token_RTKL[3] = a3;
        _Token_RTKL[4] = a4;
        _Token_Bullet = bullet;
    }
    
    // Function for owner to pull out AMMO
    function pullOutAMMO(address to, uint256 amount) public OwnerOnly returns (bool) {
        ERC20 bulletToken = ERC20(_Token_Bullet);
        
        require (
            bulletToken.balanceOf(address(this)) >= amount, 
            "Insufficeint AMMO balance in the contract"
        );
        
        return bulletToken.transfer(to, amount);
    }
    
    // Function to get amount of minimum required RTK in the contract
    function getMinimumRequiredRTKAmount() public view OwnerOnly returns (uint256) {
        uint256 netExtCirculation = 0;
        for(uint i = 1; i <= 4; i++) {
            netExtCirculation += _RTKLX_ExtCirculation[i] - ERC20(_Token_RTKL[i]).balanceOf(address(0));
        }
        
        return netExtCirculation;
    }
    
    // Function for owner to pull out EXCESS RTK. A certain minimum amount RTK has to stay within the contract
    // In order to facilitate conversion of RTKLX into RTK for all the UNBURNED RTKLX in the circulation.
    function pullOutExcessRTK(address to, uint256 amount) public OwnerOnly returns (bool) {
        ERC20 RTKToken = ERC20(_Token_RTKL[0]);
        
        require (
            RTKToken.balanceOf(address(this)) >= amount,
            "Input amount value larger than balance of swap contract"
        );
        
        require (
            (RTKToken.balanceOf(address(this)) - amount) >= getMinimumRequiredRTKAmount(),
            "Cannot withdraw an amount that leaves swap contract deficient of minimum required RTK"
        );
        
        return RTKToken.transfer(to, amount);
    }
    
    // Funciton for owner to pull out RTKLX_Token
    function pullOutRTKLX(address to, uint256 amount, uint256 X) public OwnerOnly returns (bool) {
        require (
            (X >= 2 && X <= 5), 
            "Invalid value of X. X can only be 2, 3, 4, 5"
        );
        
        ERC20 RTKLXToken = ERC20(_Token_RTKL[X-1]);
        require (
            RTKLXToken.balanceOf(address(this)) >= amount,
            "Insufficeint RTKLX balance in the swap contract. Amount value too high."
        );
        
        return RTKLXToken.transfer(to, amount);
    }
    
    function convertRTKIntoRTKLX(address to, uint256 amount, uint256 X) public returns (bool) {
        require (
            (X >= 2 && X <= 5), 
            "Invalid value of X. X can only be 2, 3, 4, 5"
        );
        
        ERC20 bulletToken = ERC20(_Token_Bullet);
        ERC20 RTKToken = ERC20(_Token_RTKL[0]);
        ERC20 RTKLX_Token = ERC20(_Token_RTKL[X-1]);
        
        require (
            RTKLX_Token.balanceOf(address(this)) >= amount,
            "Insufficeint RTKLX Token balance in the contract for the given value of X"
        );
        
        require (
            RTKToken.allowance(msg.sender, address(this)) >= amount,
            "Allowance Lower than required for RTKToken"
        );
        
        require (
            bulletToken.allowance(msg.sender, address(this)) >= ((X-1)*amount),
            "Allowance Lower than required for bulletToken"
        );
        
    
        if(bulletToken.transferFrom(msg.sender, address(this), amount)) {
            if(RTKToken.transferFrom(msg.sender, address(this), amount)) {
                if(RTKLX_Token.transfer(to, amount)) {
                    _RTKLX_ExtCirculation[X-1] += amount;
                    return true;
                } else {
                    return false;
                }
            } else {
                bulletToken.transfer(msg.sender, amount);
                return false;
            }
        } else {
            return false;
        }
    }
    
    function convertRTKLXIntoRTK(address to, uint256 amount, uint256 X) public returns (bool) {
        require (
            (X >= 2 && X <= 5), 
            "Invalid value of X. X can only be 2, 3, 4, 5"
        );
        
        ERC20 RTKToken = ERC20(_Token_RTKL[0]);
        ERC20 RTKLX_Token = ERC20(_Token_RTKL[X-1]);
            
        require (
            RTKToken.balanceOf(address(this)) >= amount,
            "Insufficeint RTK Token balance in the contract"
        );
        
        require (
            RTKLX_Token.allowance(msg.sender, address(this)) >= amount,
            "Allowance Lower than required for RTKToken"
        );
        
        if(RTKLX_Token.transferFrom(msg.sender, address(this), amount)) {
            _RTKLX_ExtCirculation[X-1] -= amount;
            return RTKToken.transfer(to, amount);
        } else {
            return false;
        }
    }
}
