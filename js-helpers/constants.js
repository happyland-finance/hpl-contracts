module.exports = {
    getNFTSaleFeeTo: function(chainId) {
        if (chainId == 56) {
            return "0x7bca710562554D25bdE896296e174659166c652e"
        } 
        return "0x19a9e6E92e8A896cF3e23eC5B862edDa82bF65ea"
    },

    getWareHousePrice: function(chainId) {
        return "0.1"    //bnb
    },

    getLandPrices: function(chainId) {
        return {rarites: [1, 2, 3], prices: ["0.1", "0.2", "0.3"]}
    }
}