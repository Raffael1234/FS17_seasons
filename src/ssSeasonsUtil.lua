---------------------------------------------------------------------------------------------------------
-- ssSeasonsUtil SCRIPT
---------------------------------------------------------------------------------------------------------
-- Purpose:  Calculate current day of the week using gametime (Mon-Sun)
-- Authors:  Jarvixes, reallogger, theSeb
--

ssSeasonsUtil = {}

ssSeasonsUtil.weekDays = nil
ssSeasonsUtil.weekDaysShort = nil
ssSeasonsUtil.seasons = nil

ssSeasonsUtil.daysInWeek = 7
ssSeasonsUtil.seasonsInYear = 4
ssSeasonsUtil.daysInSeason = 10

ssSeasonsUtil.settingsProperties = { "daysInWeek", "seasonsInYear", "daysInSeason" }

function ssSeasonsUtil.preSetup()
    ssSettings.add("seasons", ssSeasonsUtil)
end

function ssSeasonsUtil.setup()
    ssSettings.load("seasons", ssSeasonsUtil)

    ssSeasonsUtil.weekDays = {
        ssLang.getText("SS_WEEKDAY_MONDAY", "Monday"),
        ssLang.getText("SS_WEEKDAY_TUESDAY", "Tuesday"),
        ssLang.getText("SS_WEEKDAY_WEDNESDAY", "Wednesday"),
        ssLang.getText("SS_WEEKDAY_THURSDAY", "Thursday"),
        ssLang.getText("SS_WEEKDAY_FRIDAY", "Friday"),
        ssLang.getText("SS_WEEKDAY_SATURDAY", "Saturday"),
        ssLang.getText("SS_WEEKDAY_SUNDAY", "Sunday"),
    }

    ssSeasonsUtil.weekDaysShort = {
        ssLang.getText("SS_WEEKDAY_MON", "Mon"),
        ssLang.getText("SS_WEEKDAY_TUE", "Tue"),
        ssLang.getText("SS_WEEKDAY_WED", "Wed"),
        ssLang.getText("SS_WEEKDAY_THU", "Thu"),
        ssLang.getText("SS_WEEKDAY_FRI", "Fri"),
        ssLang.getText("SS_WEEKDAY_SAT", "Sat"),
        ssLang.getText("SS_WEEKDAY_SUN", "Sun"),
    }

    ssSeasonsUtil.seasons = {
        [0] = ssLang.getText("SS_SEASON_SPRING", "Spring"),
        ssLang.getText("SS_SEASON_SUMMER", "Summer"),
        ssLang.getText("SS_SEASON_AUTUMN", "Autumn"),
        ssLang.getText("SS_SEASON_WINTER", "Winter"),
    }

    addModEventListener(ssSeasonsUtil)
end

function ssSeasonsUtil:loadMap(name)
    g_currentMission.environment:addDayChangeListener(self)
end

function ssSeasonsUtil:deleteMap()
end

function ssSeasonsUtil:mouseEvent(posX, posY, isDown, isUp, button)
end

function ssSeasonsUtil:keyEvent(unicode, sym, modifier, isDown)
end

function ssSeasonsUtil:update(dt)
end

function ssSeasonsUtil:draw()
end

-- Get the current day number
function ssSeasonsUtil:currentDayNumber()
    return g_currentMission.environment.currentDay
end

-- Get the day within the week
-- assumes that day 1 = monday
-- If no day supplied, uses current day
function ssSeasonsUtil:dayOfWeek(dayNumber)
    if (dayNumber == nil) then
        dayNumber = self:currentDayNumber()
    end

    return ((dayNumber - 1) % self.daysInWeek) + 1
end

-- Get the season number.
-- If no day supplied, uses current day
function ssSeasonsUtil:season(dayNumber)
    if (dayNumber == nil) then
        dayNumber = self:currentDayNumber()
    end

    return math.fmod(math.floor(dayNumber / self.daysInSeason), self.seasonsInYear)
end

-- This function calculates the real-ish daynumber from an ingame day number
-- Used by function that calculate a realistic weather / etc
-- Spring: Mar (60)  - May (151)
-- Summer: Jun (152) - Aug (243)
-- Autumn: Sep (244) - Nov (305)
-- Winter: Dec (335) - Feb (59)
-- FIXME(jos): Of course, this changes on the southern hemisphere
function ssSeasonsUtil:julianDay(dayNumber)
    local season, partInSeason, dayInSeason
    local starts = {[0] = 60, 152, 244, 335 }

    season = self:season(dayNumber)
    dayInSeason = dayNumber % self.daysInSeason
    partInSeason = dayInSeason / self.daysInSeason

    return math.fmod(math.floor(starts[season] + partInSeason * 91), 365)
end

function ssSeasonsUtil:julanDayToDayNumber(julianDay)
    local season, partInSeason, start

    if julianDay < 60 then
        season = 3 -- winter
        start = 335
    elseif julianDay < 152 then
        season = 0 -- spring
        start = 60
    elseif julianDay < 244 then
        season = 1 -- summer
        start = 152
    elseif julianDay < 335 then
        season = 2 -- autumn
        start = 224
    end

    partInSeason = (julianDay - start) / 61.5

    return season * self.daysInSeason + math.floor(partInSeason * self.daysInSeason)
end

-- Get season name for given day number
-- If no day number supplied, uses current day
function ssSeasonsUtil:seasonName(dayNumber)
    return self.seasons[self:season(dayNumber)]
end

-- 1 = spring, 3 = winter
function ssSeasonsUtil:isSeason(seasonNumber)
    return self:season() == seasonNumber
end

-- Get day name for given day number
-- If no day number supplied, uses current day
function ssSeasonsUtil:dayName(dayNumber)
    return self.weekDays[self:dayOfWeek(dayNumber)]
end

-- Get short day name for given day number
-- If no day number supplied, uses current day
function ssSeasonsUtil:dayNameShort(dayNumber)
    return self.weekDaysShort[self:dayOfWeek(dayNumber)]
end

function ssSeasonsUtil:nextWeekDayNumber(currentDay)
    return (currentDay + 1) % self.daysInWeek
end

function ssSeasonsUtil:dayChanged()
    if ssSeasonsMod.enabled then
        local currentSeason = self:season()

        if currentSeason ~= ssSeasonsMod.latestSeason then
            ssSeasonsMod.latestSeason = currentSeason

            for _, target in pairs(ssSeasonsMod.seasonListeners) do
                -- No check here, let it crash if the function is missing
                target.seasonChanged(target)
            end
        end
    end
end

--Outputs a random sample from a triangular distribution
function ssSeasonsUtil:ssTriDist(m)
    local pmode = {}
    local p = {}

    --math.randomseed( os.time() )
    math.random()

    pmode = (m[2]-m[1])/(m[3]-m[1])
    p = math.random()
    if p < pmode then
        return math.sqrt(p*(m[3]-m[1])*(m[2]-m[1]))+m[1]
    else
        return m[3]-math.sqrt((1-p)*(m[3]-m[1])*(m[3]-m[2]))
    end
end

-- Approximation of the inverse CFD of a normal distribution
-- Based on A&S formula 26.2.23 - thanks to John D. Cook
function ssSeasonsUtil:RationalApproximation(t)
    local c = {2.515517, 0.802853, 0.010328}
    local d = {1.432788, 0.189269, 0.001308}

    return t - ((c[3]*t + c[2])*t + c[1]) / (((d[3]*t + d[2])*t + d[1])*t + 1.0)
end

-- Outputs a random sample from a normal distribution with mean mu and standard deviation sigma
function ssSeasonsUtil:ssNormDist(mu,sigma)
    local p = math.random()

    if p < 0.5 then
        return self:RationalApproximation(math.sqrt(-2.0 * math.log(p))) * -sigma + mu
    else
        return self:RationalApproximation(math.sqrt(-2.0 * math.log(1 - p))) * sigma + mu
    end
end

-- Outputs a random sample from a lognormal distribution
function ssSeasonsUtil:ssNormDist(beta, gamma) 
		
	local p = math.random();
    local z
	
	if p < 0.5 then
		z = self:RationalApproximation( math.sqrt(-2.0*math.log(p)))*-1
	else
		z = self:RationalApproximation( math.sqrt(-2.0*math.log(1-p)))
	end

    return gamma * math.exp ( z / beta )
end

-- Does one iteration step of density layer update calling provided function for specified area.
-- Returns values for next iteration. Extra arguments are passed on to the provided function.
-- Calling function should keep currentX and CurrentZ between calls to the function. 
function ssSeasonsUtil:ssItterateOverTerrain( currentX, currentZ, func, ... )

    local moreIterations=true;
    local mapSegments = 16; -- Must be evenly dividable with mapsize.
    
    if g_currentMission.missionInfo.timeScale > 120 then
        mapSegments = 1; -- Not enought time to do it section by section since it might be called every two hour as worst case.
    end;

    local startWorldX =  currentX * g_currentMission.terrainSize / mapSegments - g_currentMission.terrainSize / 2;
    local startWorldZ =  currentZ * g_currentMission.terrainSize / mapSegments - g_currentMission.terrainSize / 2;
    local widthWorldX = startWorldX + g_currentMission.terrainSize / mapSegments - 0.1; -- -0.1 to avoid overlap.
    local widthWorldZ = startWorldZ;
    local heightWorldX = startWorldX;
    local heightWorldZ = startWorldZ + g_currentMission.terrainSize / mapSegments - 0.1; -- -0.1 to avoid overlap.

    -- Extra arguments are optional
    if arg == nil then
        func(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
    else
         func(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, unpack(arg));
    end;
    
    if currentZ < mapSegments - 1 then -- Starting with column 0 So index of last column is one less then the number of columns.
        -- Next column
        currentZ = currentZ + 1;
    elseif  currentX < mapSegments - 1 then -- Starting with row 0
        -- Next row
        currentX = currentX + 1;
        currentZ = 0;
    else
        -- Done with the loop, set up for the next one.
        currentX = 0;
        currentZ = 0;
        moreIterations = false;
    end
    
    return currentX, currentZ, moreIterations
end;