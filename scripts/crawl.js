require('dotenv').config()
const BigNumber = require('bignumber.js')
const Web3 = require('web3')
var fs = require('fs')
let staking = '0x69C01f0bef6123a92248Cc4F35638760F9059497'
let StakingABI = require('../abi/MasterChef.json')
const sleep = require('sleep-promise')
let fromBlock = 14212495
let rpcs = [
  'https://speedy-nodes-nyc.moralis.io/6f1c50d092cad31805b2371f/bsc/mainnet',
]

console.log(rpcs)
function getRandomRPC() {
  let r = Math.floor(Math.random() * 2)
  return rpcs[r]
}

let stakeAddressMap = {}

async function getWeb3() {
  let provider = getRandomRPC()
  let web3 = new Web3(
    new Web3.providers.HttpProvider(provider, { timeout: 3000 }),
  )
  try {
    await web3.eth.getBlockNumber()
  } catch (e) {
    provider = getRandomRPC()
    web3 = new Web3(
      new Web3.providers.HttpProvider(provider, { timeout: 3000 }),
    )
  }
  return web3
}

async function crawl(from, to, bid) {
  let step = 1000

  let lastBlock = to
  let lastCrawl = from
  while (lastBlock - lastCrawl > 0) {
    try {
      let web3 = await getWeb3()
      let toBlock
      toBlock = lastCrawl + step

      console.log(
        `${bid}: Get Past Event from block ${lastCrawl + 1} to ${toBlock}`,
      )
      {
        let contract = new web3.eth.Contract(StakingABI, staking)

        let evts = await contract.getPastEvents('Deposit', {
          fromBlock: lastCrawl + 1,
          toBlock: toBlock,
        })

        if (!evts) {
          evts = []
        }

        console.log(
          `there are ${evts.length} events from ${lastCrawl + 1} to ${toBlock}`,
        )

        for (let i = 0; i < evts.length; i++) {
          let event = evts[i]
          if (!stakeAddressMap[event.returnValues.user.toLowerCase()]) {
            while (true) {
              try {
                let web3 = await getWeb3()
                let contract = new web3.eth.Contract(StakingABI, staking)
                let userInfo = await contract.methods
                  .getUserInfo(0, event.returnValues.user)
                  .call()
                if (
                  new BigNumber(userInfo.stakeAmount).comparedTo(
                    new BigNumber('1e22'),
                  ) >= 0
                ) {
                  stakeAddressMap[event.returnValues.user.toLowerCase()] = true
                }
                break
              } catch (e) {
                console.error('stake error', e)
                await sleep(1000)
              }
            }
          }
        }
      }

      lastCrawl = toBlock
    } catch (e) {
      console.error(e)
    }
  }
}

async function getAddressList() {
  try {
    let web3 = await getWeb3()
    let lastBlock = await web3.eth.getBlockNumber()
    let lastCrawl = fromBlock
    let numBatches = 20
    let blockPerBatch = Math.floor((lastBlock - lastCrawl) / numBatches)
    let batches = []
    let tasks = []
    for (var i = 0; i < numBatches; i++) {
      batches.push({
        from: lastCrawl + i * blockPerBatch,
        to:
          lastCrawl + (i + 1) * blockPerBatch > lastBlock
            ? lastBlock
            : lastCrawl + (i + 1) * blockPerBatch,
      })
    }

    for (const b of batches) {
      tasks.push(crawl(b.from, b.to, batches.indexOf(b)))
    }
    await Promise.all(tasks)

    console.log('save all addresses', Object.values(stakeAddressMap).length)

    let stakeAddressList = Object.keys(stakeAddressMap)

    var json = JSON.stringify(stakeAddressList)
    fs.writeFile('stakeAddressList.json', json, 'utf8', function () {})
  } catch (e) {
    console.error('failed', e)
    process.exit(1)
  }
}

getAddressList()
