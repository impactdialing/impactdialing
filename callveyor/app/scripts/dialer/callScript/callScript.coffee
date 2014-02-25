'use strict'

callScript = angular.module('callveyor.dialer.callScript', [])

callScript.config(['$stateProvider', ($stateProvider) ->

])

callScript.controller('SurveyFormCtrl', [
  '$scope', '$filter'
  ($scope,   $filter) ->
    console.log 'SurveyFormCtrl', $scope.dialer.callScript

    normalizeObj = (object, type) ->
      console.log 'normalizeObj', object, type
      obj = {
        id: object.id
        order: object.script_order
        type: ''
        content: ''
      }
      switch type
        when 'notes'
          obj.type = 'note'
          obj.content = object.note
        when 'script_texts'
          obj.type = 'scriptText'
          obj.content = object.content
        when 'questions'
          obj.type = 'question'
          obj.content = object.text
          obj.possibleResponses = object.possible_responses
        else
          console.log 'not normalizing', type
          # todo: handle error or fail quietly when normalizing survey
      obj

    normalizedSurvey = []
    normalizeSurvey  = (arr, type) ->
      console.log 'normalizeSurvey', arr, type
      switch type
        when 'notes', 'script_texts', 'questions'
          angular.forEach(arr, (obj) ->
            normalizedSurvey.push(normalizeObj(obj, type))
          )

    angular.forEach($scope.dialer.callScript, (obj, type) ->
      normalizeSurvey(obj, type)
    )
    $scope.dialer.survey = $filter('orderBy')(normalizedSurvey, 'order')
])

callScript.directive('idSurveyForm', [
  ->
    # templates = {
    #   wrap: '<div class="well">'
    #   per: '</div>'
    #   scriptText: '<pre>{{text}}</pre>'
    #   note: '<label for="note_{{id}}">Don\'t forget to use some notes!</label><input id="note_{{id}}" class="form-control">'
    #   question: '<label for="question_{{id}}">{{text}}</label><select id="question_{{id}}" class="form-control"><option data-ng-repeat="possible_responses" value="{{id}}">{{text}}</option></select>'
    # }

    # linkFn = (scope, element, attrs) ->
    #   console.log 'idSurveyForm linkFn', scope.dialer.survey
    #   tpl = ''
    #   angular.forEach(scope.dialer.survey, (obj) ->
    #     tpl += templates.wrap
    #     tpl += templates[obj.type]
    #     tpl += templates.per
    #   )
      # scope.rootDirectory = 'images/';
      # element.html(tpl).show();
      # $compile(element.contents())(scope);

    console.log 'idSurveyForm'
    {
      transclude: true
      controller: 'SurveyFormCtrl'
    }
])