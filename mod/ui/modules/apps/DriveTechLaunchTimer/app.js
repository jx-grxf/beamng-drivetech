// DriveTech 0-100 Timer
// Arms automatically while the car stands still and starts timing the moment it
// moves. Shows 0-100 km/h big, plus 0-50, 0-200, 100-200 km/h and the 1/4 mile.
angular.module('beamng.apps')
.directive('driveTechLaunchTimer', [function () {
  return {
    template: `
      <div class="bngApp" style="width:100%; height:100%; background-color: rgba(0,0,0,0.65); color:#fff; padding:8px; box-sizing:border-box; font-family: inherit; display:flex; flex-direction:column;">
        <div style="display:flex; justify-content:space-between; align-items:center; font-size:0.75em; opacity:0.8;">
          <span>0-100 km/h</span>
          <span ng-style="{color: stateColor}">{{ stateText }}</span>
        </div>
        <div style="font-size:2.6em; font-weight:bold; line-height:1.1; text-align:center; margin:4px 0;">{{ main }}</div>
        <div style="font-size:0.75em; text-align:center; opacity:0.7; margin-bottom:6px;">Best: {{ best }}</div>
        <table style="width:100%; font-size:0.8em; border-collapse:collapse;">
          <tr ng-repeat="row in rows track by $index">
            <td style="opacity:0.8;">{{ row.label }}</td>
            <td style="text-align:right; font-weight:bold;">{{ row.value }}</td>
          </tr>
        </table>
      </div>`,
    replace: true,
    restrict: 'EA',
    link: function (scope) {
      var streamsList = ['electrics']
      StreamsManager.add(streamsList)
      scope.$on('$destroy', function () {
        StreamsManager.remove(streamsList)
      })

      var QUARTER_MILE = 402.336
      var state = 'waiting' // waiting -> ready -> running -> done
      var startTime = 0
      var lastNow = 0
      var lastKmh = 0
      var maxKmh = 0
      var distance = 0
      var results = {}
      var bestTime = null

      function fmt(t) { return t === undefined || t === null ? '--.--' : t.toFixed(2) + ' s' }

      function setState(newState) {
        state = newState
        var map = {
          waiting: ['STOP', '#aaaaaa'],
          ready: ['READY', '#4cd964'],
          running: ['RUNNING', '#ffcc00'],
          done: ['DONE', '#5ac8fa']
        }
        scope.stateText = map[newState][0]
        scope.stateColor = map[newState][1]
      }

      function render(now) {
        var running = state === 'running'
        var elapsed = running ? (now - startTime) / 1000 : null
        scope.main = results.t100 !== undefined ? fmt(results.t100) : (running ? fmt(elapsed) : '--.--')
        scope.best = fmt(bestTime)
        var t200from100 = (results.t200 !== undefined && results.t100 !== undefined) ? results.t200 - results.t100 : undefined
        scope.rows = [
          { label: '0-50 km/h', value: fmt(results.t50) },
          { label: '0-200 km/h', value: fmt(results.t200) },
          { label: '100-200 km/h', value: fmt(t200from100) },
          { label: '1/4 mile', value: results.tQuarter !== undefined ? fmt(results.tQuarter) + ' @ ' + results.vQuarter.toFixed(0) + ' km/h' : '--.--' }
        ]
      }

      // linear interpolation of the exact crossing time between two samples
      function crossing(target, prevKmh, kmh, prevT, t) {
        if (kmh === prevKmh) return t
        return prevT + (t - prevT) * (target - prevKmh) / (kmh - prevKmh)
      }

      setState('waiting')
      render(performance.now())

      scope.$on('streamsUpdate', function (event, streams) {
        if (!streams.electrics) return
        var now = performance.now()
        var dt = lastNow ? (now - lastNow) / 1000 : 0
        var kmh = (streams.electrics.wheelspeed || 0) * 3.6

        scope.$evalAsync(function () {
          if (state === 'waiting' || state === 'done') {
            if (kmh < 0.5) {
              setState('ready')
            }
          } else if (state === 'ready') {
            if (kmh >= 0.5) {
              startTime = lastNow && lastKmh < 0.5 ? crossing(0.5, lastKmh, kmh, lastNow, now) : now
              distance = 0
              maxKmh = kmh
              results = {}
              setState('running')
            }
          } else if (state === 'running') {
            distance += (kmh / 3.6) * dt
            var t = function (target) { return (crossing(target, lastKmh, kmh, lastNow, now) - startTime) / 1000 }
            if (results.t50 === undefined && kmh >= 50) results.t50 = t(50)
            if (results.t100 === undefined && kmh >= 100) {
              results.t100 = t(100)
              if (bestTime === null || results.t100 < bestTime) bestTime = results.t100
            }
            if (results.t200 === undefined && kmh >= 200) results.t200 = t(200)
            if (results.tQuarter === undefined && distance >= QUARTER_MILE) {
              results.tQuarter = (now - startTime) / 1000
              results.vQuarter = kmh
            }
            maxKmh = Math.max(maxKmh, kmh)
            // run ends when the car slows down clearly or stops
            if (kmh < maxKmh - 5 || kmh < 0.5) setState(results.t100 !== undefined ? 'done' : 'waiting')
          }
          lastNow = now
          lastKmh = kmh
          render(now)
        })
      })
    }
  }
}])
