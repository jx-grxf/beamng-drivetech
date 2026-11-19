// DriveTech Bus
// Driver display for the DriveTech bus setups: retarder level and braking, doors, kneeling
// and the stop brake that holds the bus while a door is open.
angular.module('beamng.apps')
.directive('driveTechBus', [function () {
  return {
    template: `
      <div class="bngApp" style="width:100%; height:100%; background-color: rgba(0,0,0,0.65); color:#fff; padding:8px; box-sizing:border-box; font-family: inherit; display:flex; flex-direction:column; gap:6px; overflow:hidden;">
        <div ng-if="!hasRetarder" style="font-size:0.8em; opacity:0.7;">Kein DriveTech-Bus-Setup</div>
        <div ng-if="hasRetarder" style="display:flex; flex-direction:column; gap:4px;">
          <div style="display:flex; justify-content:space-between; font-size:0.75em; opacity:0.8;">
            <span>Retarder</span><span>Alt+Y / Alt+H</span>
          </div>
          <div style="display:flex; align-items:center; gap:4px;">
            <div ng-click="change(-1)" style="cursor:pointer; padding:2px 8px; border-radius:3px; background-color:rgba(255,255,255,0.15);">&minus;</div>
            <div style="flex:1; text-align:center; font-weight:bold; font-size:1.15em;">{{ levelText }}</div>
            <div ng-click="change(1)" style="cursor:pointer; padding:2px 8px; border-radius:3px; background-color:rgba(255,255,255,0.15);">+</div>
          </div>
          <div style="display:flex; gap:2px;">
            <div ng-repeat="s in stages" style="flex:1; height:5px; border-radius:1px;"
                 ng-style="{'background-color': s <= stage ? '#d4892a' : 'rgba(255,255,255,0.15)'}"></div>
          </div>
          <div style="height:4px; background:rgba(255,255,255,0.15); border-radius:2px;">
            <div style="height:100%; background:#5ac8fa; border-radius:2px;" ng-style="{width: braking + '%'}"></div>
          </div>
        </div>
        <div style="display:flex; gap:4px; font-size:0.75em;">
          <div ng-repeat="l in lamps" style="flex:1; text-align:center; padding:3px 0; border-radius:3px;"
               ng-style="{'background-color': l.on ? l.color : 'rgba(255,255,255,0.1)', opacity: l.on ? 1 : 0.5}">{{ l.label }}</div>
        </div>
      </div>`,
    replace: true,
    restrict: 'EA',
    link: function (scope) {
      var streamsList = ['electrics']
      StreamsManager.add(streamsList)
      scope.$on('$destroy', function () {
        StreamsManager.remove(streamsList)
      })

      // retarderControl orders its settings as auto, off, then the manual levels
      var LEVELS = ['Auto', 'Aus', 'Stufe 1', 'Stufe 2', 'Stufe 3', 'Stufe 4', 'Stufe 5']
      scope.stages = [1, 2, 3, 4, 5]
      scope.stage = 0
      scope.levelText = ''
      scope.braking = 0
      scope.hasRetarder = false
      scope.lamps = [
        {key: 'doors', label: 'Türen', color: '#d4892a', on: false},
        {key: 'stop', label: 'Haltebremse', color: '#ff453a', on: false},
        {key: 'kneel', label: 'Kneeling', color: '#2a7fd4', on: false}
      ]

      scope.change = function (step) {
        bngApi.activeObjectLua("controller.getControllerSafe('retarderControl').changeRetarderSettingIndex(" + step + ")")
      }

      scope.$on('streamsUpdate', function (event, streams) {
        var e = streams.electrics
        if (!e) return
        scope.$evalAsync(function () {
          var index = e.retarder_levelIndex
          scope.hasRetarder = typeof index === 'number'
          if (scope.hasRetarder) {
            scope.levelText = LEVELS[index - 1] || ''
            scope.stage = index >= 3 ? index - 2 : 0
            scope.braking = Math.round(Math.min(Math.max(e.retarder_actual || 0, 0), 1) * 100)
          }
          var doorsOpen = (e.dooropen || 0) > 0
          scope.lamps[0].on = doorsOpen
          // the stock bus controller holds the brake while a door is open below 2 m/s
          scope.lamps[1].on = doorsOpen && (e.wheelspeed || 0) < 2
          scope.lamps[2].on = (e.kneel || 0) > 0
        })
      })
    }
  }
}])
