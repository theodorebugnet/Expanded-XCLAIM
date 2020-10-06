//SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >= 0.5.0 < 0.7.0;

contract ExchangeOracle {
    /// Mock exchange rate oracle between BTC (and BTC-backed tokens), and ETH.
    /// Hardcoded to 1 BTC = 2 ETH.
    /// @param btc The amount of BTC to convert to ETH.
    /// @return The corresponding amount of ETH.
    function btcToEth(uint btc) public returns (uint) {
        //TODO: this is mock
        uint exchangeRate = 2;
        return btc * exchangeRate;
    }
}
