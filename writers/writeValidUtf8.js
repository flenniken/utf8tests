#!/usr/bin/env node

// Read a binary file and write a utf-8 file.

function writeValidUtf8(inFilename, outFilename, skipOrReplace) {
  // Read the binary file input file, which might contain invalid
  // UTF-8 bytes, then write valid UTF-8 bytes to the output file
  // either skipping the invalid bytes or replacing them with U-FFFD.
  // When there is an error, display the error message to standard out
  // and return 1, else return 0.  The input file must be under 50k.

  const fs = require('fs')

  // Read the data as binary.
  try {
    var data = fs.readFileSync(inFilename)
  }
  catch (err) {
    console.log("Error reading the input file: " + inFilename)
    return 1
  }

  // Encode the data as UTF-8.
  var newData = Buffer.from(data, 'utf-8').toString();

  // Write the data.
  try {
    fs.writeFileSync(outFilename, newData)
  }
  catch (err) {
    console.log('Error writing the file: ' + outFilename)
    return 1
  }

  return 0 // success
}

function main() {
  // console.log(process.argv);

  // Parse the command line parameters.
  var msg = 'usage: writeValidUtf8t.js inFilename, outFilename, (skip | replace)'
  if (process.argv.length < 5) {
    console.log(msg)
    return 1
  }
  option = process.argv[4]
  if (option != 'skip' && option != 'replace') {
    console.log(msg)
    return 1
  }

  var inFilename = process.argv[2]
  var outFilename = process.argv[3]
  writeValidUtf8(inFilename, outFilename, option)
}

return main()
