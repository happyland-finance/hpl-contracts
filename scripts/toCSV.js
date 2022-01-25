let input = require('./stakeAddressTickets.json')
const createCsvWriter = require('csv-writer').createObjectCsvWriter
const csvWriter = createCsvWriter({
  path: 'stakeAddressTickets.csv',
  header: [
    { id: 'address', title: 'Address' },
    { id: 'ticket', title: 'Tickets' },
  ],
})
let records = []
for (const addr of Object.keys(input)) {
  if (input[addr]) {
    records.push({
      address: addr,
      ticket: input[addr],
    })
  }
}

csvWriter
  .writeRecords(records) // returns a promise
  .then(() => {
    console.log('...Done')
  })
