'use strict'

detect = angular.module('idDeviceDetect', [])

detect.factory('idDeviceDetectFactory', [
  '$window',
  ($window) ->
    factory = {}

    factory.isMobile = ->
      console.log('idDeviceDetectFactory.isMobile')
      unless angular.isFunction(window.matchMedia)
        return false
      else
        return $window.matchMedia('(max-width: 767px)').matches

    factory
])
