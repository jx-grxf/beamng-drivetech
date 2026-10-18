// DriveTech Rain
// Rain with wet roads on or off, rain intensity, and aquaplaning (only while it rains).
// The work happens in the GE extension driveTechRain and the vehicle extension driveTechAquaplaning.
angular.module('beamng.apps')
.directive('driveTechRain', [function () {
  return {
    template: `
      <div class="bngApp" style="width:100%; height:100%; background-color: rgba(0,0,0,0.65); color:#fff; padding:8px; box-sizing:border-box; font-family: inherit; display:flex; flex-direction:column; gap:5px; overflow:hidden;">
        <div style="font-size:0.75em; opacity:0.8;">Regen / nasse Straße</div>
        <div ng-click="toggle()" style="cursor:pointer; text-align:center; font-weight:bold; font-size:1.1em; padding:5px 0; border-radius:4px;"
             ng-style="{'background-color': enabled ? '#2a7fd4' : 'rgba(255,255,255,0.15)'}">
          {{ enabled ? 'REGEN AN' : 'REGEN AUS' }}
        </div>
        <div style="display:flex; gap:3px;">
          <div ng-repeat="i in intensities" ng-click="setIntensity(i.key)" style="flex:1; cursor:pointer; text-align:center; font-size:0.75em; padding:3px 0; border-radius:3px;"
               ng-style="{'background-color': intensity === i.key ? '#2a7fd4' : 'rgba(255,255,255,0.12)'}">{{ i.label }}</div>
        </div>

        <div style="border-top:1px solid rgba(255,255,255,0.2); margin-top:2px; padding-top:5px; display:flex; flex-direction:column; gap:5px;"
             ng-style="{opacity: enabled ? 1 : 0.4}">
          <div ng-click="toggleAquaplaning()" style="text-align:center; font-weight:bold; font-size:0.95em; padding:4px 0; border-radius:4px;"
               ng-style="{'cursor': enabled ? 'pointer' : 'default', 'background-color': aquaplaning ? '#d4892a' : 'rgba(255,255,255,0.15)'}">
            {{ aquaplaning ? 'AQUAPLANING AN' : 'AQUAPLANING AUS' }}
          </div>
          <div style="display:flex; align-items:center; gap:3px; font-size:0.7em;">
            <span style="opacity:0.8; margin-right:2px;">Profil</span>
            <div ng-repeat="t in treads" ng-click="setTread(t)" style="flex:1; cursor:pointer; text-align:center; padding:2px 0; border-radius:3px;"
                 ng-style="{'background-color': tread === t ? '#d4892a' : 'rgba(255,255,255,0.12)'}">{{ t }}</div>
            <span style="opacity:0.8;">mm</span>
          </div>
          <div style="font-size:0.7em;">
            <div style="display:flex; justify-content:space-between; opacity:0.8;">
              <span>Wasserfilm</span><span>{{ water.toFixed(1) }} mm</span>
            </div>
            <div style="height:4px; background:rgba(255,255,255,0.15); border-radius:2px; margin-top:2px;">
              <div style="height:100%; background:#5ac8fa; border-radius:2px;" ng-style="{width: waterPercent + '%'}"></div>
            </div>
          </div>
          <div ng-if="aquaplaning && enabled" style="display:flex; align-items:center; gap:8px;">
            <div style="display:grid; grid-template-columns: 14px 14px; gap:3px 10px;">
              <div ng-repeat="w in wheels track by w.name" title="{{ w.name }}" style="width:14px; height:22px; border-radius:3px; border:1px solid rgba(255,255,255,0.5);"
                   ng-style="{'background-color': wheelColor(w.lift)}"></div>
            </div>
            <div style="flex:1; font-size:0.7em; line-height:1.3;">
              <div ng-if="warning" style="font-weight:bold; font-size:1.3em; color:#ff453a;">AQUAPLANING!</div>
              <div ng-if="!warning && critical" style="opacity:0.8;">ab ca. {{ critical }} km/h</div>
              <div ng-if="!warning && !critical" style="opacity:0.6;">kein stehendes Wasser</div>
            </div>
          </div>
        </div>
      </div>`,
    replace: true,
    restrict: 'EA',
    link: function (scope) {
      var WHEEL_ORDER = ['FL', 'FR', 'RL', 'RR']
      var MAX_WATER = 6
      var lastWheelData = 0

      scope.intensities = [
        {key: 'light', label: 'Leicht'},
        {key: 'medium', label: 'Mittel'},
        {key: 'heavy', label: 'Stark'}
      ]
      scope.treads = [8, 5, 3, 1.6]
      scope.enabled = false
      scope.aquaplaning = false
      scope.intensity = 'medium'
      scope.tread = 8
      scope.water = 0
      scope.waterPercent = 0
      scope.wheels = []
      scope.warning = false
      scope.critical = null

      function lua(cmd) {
        bngApi.engineLua('if driveTechRain then driveTechRain.' + cmd + ' end')
      }

      scope.toggle = function () { lua('toggle()') }
      scope.setIntensity = function (key) { lua('setIntensity("' + key + '")') }
      scope.setTread = function (mm) { lua('setTread(' + mm + ')') }
      scope.toggleAquaplaning = function () {
        if (scope.enabled) lua('toggleAquaplaning()')
      }

      // green = full grip, red = tyre floats
      scope.wheelColor = function (lift) {
        if (lift < 0.05) return 'rgba(76,217,100,0.8)'
        if (lift < 0.5) return 'rgba(255,204,0,0.9)'
        return 'rgba(255,69,58,0.95)'
      }

      function setWater(mm) {
        scope.water = mm || 0
        scope.waterPercent = Math.min(100, scope.water / MAX_WATER * 100)
      }

      scope.$on('DriveTechRainState', function (event, data) {
        scope.$evalAsync(function () {
          data = data || {}
          scope.enabled = !!data.enabled
          scope.aquaplaning = !!data.aquaplaning
          scope.intensity = data.intensity || scope.intensity
          scope.tread = data.tread || scope.tread
          setWater(data.water)
        })
      })

      scope.$on('DriveTechAquaplaning', function (event, data) {
        scope.$evalAsync(function () {
          if (!data || !data.wheels) return
          lastWheelData = Date.now()
          var names = Object.keys(data.wheels).sort(function (a, b) {
            var ia = WHEEL_ORDER.indexOf(a), ib = WHEEL_ORDER.indexOf(b)
            return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib) || (a < b ? -1 : 1)
          })
          var maxLift = 0
          scope.wheels = names.map(function (name) {
            maxLift = Math.max(maxLift, data.wheels[name])
            return {name: name, lift: data.wheels[name]}
          })
          scope.warning = maxLift >= 0.5
          scope.critical = data.critical ? Math.round(data.critical / 5) * 5 : null
        })
      })

      // the vehicle stops sending when aquaplaning is off or the player switched cars
      var staleTimer = setInterval(function () {
        if (scope.wheels.length && Date.now() - lastWheelData > 1000) {
          scope.$evalAsync(function () {
            scope.wheels = []
            scope.warning = false
            scope.critical = null
          })
        }
      }, 500)
      scope.$on('$destroy', function () { clearInterval(staleTimer) })

      lua('requestState()')
    }
  }
}])
