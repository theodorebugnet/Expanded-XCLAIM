//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.0 < 0.7.0;

contract ExchangeOracle {
    function btcToEth(uint btc) public returns (uint) {
        //TODO: this is mock
        uint exchangeRate = 2;
        return btc * exchangeRate;
    }
}
