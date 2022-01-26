module.exports = {
  getNFTSaleFeeTo: function (chainId) {
    if (chainId == 56) {
      return '0x7bca710562554D25bdE896296e174659166c652e'
    }
    return '0x19a9e6E92e8A896cF3e23eC5B862edDa82bF65ea'
  },
  getStakingRewardTreasury: function (chainId) {
    if (chainId == 56) {
      return '0x43FFb1f9ebdcAA25b6b1887e81359017E66fcB5a'
    }
    return '0x4Dcfc32c29dA93fCa65A7f6Eb57b5253217846CF'
  },
  getDevRewardAddress: function (chainId) {
    if (chainId == 56) {
      return '0x726dCB5489e27E9712fC6dBc59690Fdc5aAA7e91'
    }
    return '0x4Dcfc32c29dA93fCa65A7f6Eb57b5253217846CF'
  },
  getRouter: function (chainId) {
    if (chainId == 56) {
      return '0x10ED43C718714eb63d5aA57B78B54704E256024E'
    } else if (chainId == 97) {
      return '0x3380ae82e39e42ca34ebed69af67faa0683bb5c1' //ape swap testnet
    }
    throw 'unsupported chain Id'
  },

  getWareHousePrice: function (chainId) {
    return '0.1' //bnb
  },

  getLandPrices: function (chainId) {
    return { rarites: [1, 2, 3], prices: ['0.1', '0.2', '0.3'] }
  },
  getHousePrices: function (chainId) {
    return { rarites: [1, 2, 3], prices: ['0.1', '0.2', '0.3'] }
  },
  getMarketPaymentTokens: function (chainId) {
    if (chainId == 56) {
      return ['0xe9e7cea3dedca5984780bafc599bd69add087d56']
    }
    return ['0x4fb99590ca95fc3255d9fa66a1ca46c43c34b09a']
  },

  getPairedToken: function (chainId) {
    if (chainId == 56) {
      return '0xe9e7cea3dedca5984780bafc599bd69add087d56' //busd on mainnet
    }
    return '0x4fb99590ca95fc3255d9fa66a1ca46c43c34b09a' //banana on bsc testnet
  },
  getOperator: function (chainId) {
    return '0x0b4d496fcdbcd5b1f696946276d61e13c441eca2'
  },
  getLandSalePaymentTokens: function (chainId) {
    if (chainId == 56) {
      return [
        '0xe9e7cea3dedca5984780bafc599bd69add087d56',
        '0x0d0621aD4EC89Da1cF0F371d6205229f04bCb378',
      ]
    }
    //todo: check for testnet
    return [
      '0xe9e7cea3dedca5984780bafc599bd69add087d56',
      '0x0d0621aD4EC89Da1cF0F371d6205229f04bCb378',
    ]
  },
}
