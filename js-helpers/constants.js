module.exports = {
    getNFTSaleFeeTo: function(chainId) {
        if (chainId == 56) {
            return "0x7bca710562554D25bdE896296e174659166c652e"
        } 
        return "0x19a9e6E92e8A896cF3e23eC5B862edDa82bF65ea"
    },
    getStakingRewardTreasury: function (chainId) {
        //TODO: add mainnet
        return "0xf4e1e3cD1227dFe8B03d4fF3FBC422d483b31bf7"
    },
    getRouter: function (chainId) {
        if (chainId == 56) {
            return "0x10ED43C718714eb63d5aA57B78B54704E256024E"
        } else if (chainId == 97) {
            return "0x3380ae82e39e42ca34ebed69af67faa0683bb5c1" //ape swap testnet
        }
        throw "unsupported chain Id"
    },

    getWareHousePrice: function(chainId) {
        return "0.1"    //bnb
    },

    getLandPrices: function(chainId) {
        return {rarites: [1, 2, 3], prices: ["0.1", "0.2", "0.3"]}
    },

    getPairedToken: function(chainId) {
        if (chainId == 56) {
            return "0xe9e7cea3dedca5984780bafc599bd69add087d56" //busd on mainnet
        }
        return "0x4fb99590ca95fc3255d9fa66a1ca46c43c34b09a" //banana on bsc testnet
    }
}