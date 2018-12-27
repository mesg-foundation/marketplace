module.exports = dependencies => ({
  totalServices: require('./totalServices')(dependencies),
  createService: require('./createService')(dependencies),
})
