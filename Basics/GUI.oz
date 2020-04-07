functor
import
	Module
	Input
	/* System */
export
	portWindow:StartWindow
define
	[QTk] = {Module.link ['x-oz://system/wp/QTk.ozf']}
	GeneralPort

	StartWindow
	TreatStream

	RemoveItem
	RemovePath
	RemovePlayer

	Map = Input.map

	NRow = Input.nRow
	NColumn = Input.nColumn

	DrawSubmarine
	MoveSubmarine
	DrawMine
	RemoveMine
	DrawPath

	BuildWindow

	Label
	Squares
	DrawMap

	StateModification

	UpdateLife

	DrawExplosion
	DrawDrone

	Logger = Input.logger

	Missile0   = {QTk.newImage photo(file:'res/missiles/Missile0.gif')}
	Missile45  = {QTk.newImage photo(file:'res/missiles/Missile45.gif')}
	Missile90  = {QTk.newImage photo(file:'res/missiles/Missile90.gif')}
	Missile135 = {QTk.newImage photo(file:'res/missiles/Missile135.gif')}
	Missile180 = {QTk.newImage photo(file:'res/missiles/Missile180.gif')}
	Missile225 = {QTk.newImage photo(file:'res/missiles/Missile225.gif')}
	Missile270 = {QTk.newImage photo(file:'res/missiles/Missile270.gif')}
	Missile315 = {QTk.newImage photo(file:'res/missiles/Missile315.gif')}
	Missiles = missiles(0:Missile0 45:Missile45 90:Missile90 135:Missile135 180:Missile180 225:Missile225 270:Missile270 315:Missile315)

in

%%%%% Build the initial window and set it up (call only once)
	fun{BuildWindow}
		Grid GridScore Toolbar Desc DescScore Window
	in
		Toolbar=lr(glue:we tbbutton(text:"Quit" glue:w action:toplevel#close))
		Desc=grid(handle:Grid height:500 width:500)
		/* Canvas= canvas(handle:CanvasMap width:500 height:500) */
		DescScore=grid(handle:GridScore height:100 width:500)
		Window={QTk.build td(Toolbar Desc DescScore)}

		{Window show}

		% configure rows and set headers
		{Grid rowconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..NRow do
			{Grid rowconfigure(N+1 minsize:50 weight:0 pad:5)}
			{Grid configure({Label N} row:N+1 column:1 sticky:wesn)}
		end
		% configure columns and set headers
		{Grid columnconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..NColumn do
			{Grid columnconfigure(N+1 minsize:50 weight:0 pad:5)}
			{Grid configure({Label N} row:1 column:N+1 sticky:wesn)}
		end
		% configure scoreboard
		{GridScore rowconfigure(1 minsize:50 weight:0 pad:5)}
		for N in 1..(Input.nbPlayer) do
			{GridScore columnconfigure(N minsize:50 weight:0 pad:5)}
		end

		{DrawMap Grid}

		handle(grid:Grid score:GridScore)
	end

%%%%% Squares of water and island
	Squares = square(0:label(text:"" width:1 height:1 bg:c(102 102 255))
			 1:label(text:"" borderwidth:5 relief:raised width:1 height:1 bg:c(153 76 0))
			)


%%%%% Labels for rows and columns
	fun{Label V}
		label(text:V borderwidth:5 relief:raised bg:c(255 255 255) fg:c(0 0 0) ipadx:5 ipady:5)
	end

%%%%% Function to draw the map
	proc{DrawMap Grid}
		proc{DrawColumn Column M N}
			case Column
			of nil then skip
			[] T|End then
				{Grid configure(Squares.T row:M+1 column:N+1 sticky:wesn)}
				{DrawColumn End M N+1}
			end
		end
		proc{DrawRow Row M}
			case Row
			of nil then skip
			[] T|End then
				{DrawColumn T M 1}
				{DrawRow End M+1}
			end
		end
	in
		{DrawRow Map 1}
	end

%%%%% Init the submarine
	fun{DrawSubmarine Grid ID Position}
		Handle HandlePath HandleScore X Y Id Color LabelSub LabelScore
	in
		pt(x:X y:Y) = Position
		id(id:Id color:Color name:_) = ID

		LabelSub = label(text:"S" handle:Handle borderwidth:5 relief:raised bg:Color ipadx:5 ipady:5)
		LabelScore = label(text:Input.maxDamage borderwidth:5 handle:HandleScore relief:solid bg:Color ipadx:5 ipady:5)
		HandlePath = {DrawPath Grid Color X Y}
		{Grid.grid configure(LabelSub row:X+1 column:Y+1 sticky:wesn)}
		{Grid.score configure(LabelScore row:1 column:Id sticky:wesn)}
		{HandlePath 'raise'()}
		{Handle 'raise'()}
		guiPlayer(id:ID score:HandleScore submarine:Handle mines:nil path:HandlePath|nil lastPos:Position)
	end

	fun{MoveSubmarine Position}
		fun{$ Grid State}
			ID HandleScore Handle Mine Path NewPath X Y LastPos
		in
			guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path lastPos:LastPos) = State
			pt(x:X y:Y) = Position
			NewPath = {DrawPath Grid ID.color X Y}
			{Grid.grid remove(Handle)}
			{Grid.grid configure(Handle row:X+1 column:Y+1 sticky:wesn)}
			{NewPath 'raise'()}
			{Handle 'raise'()}
			guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:NewPath|Path lastPos:Position)
		end
	end

	fun{DrawMine Position}
		fun{$ Grid State}
			ID HandleScore Handle Mine Path LabelMine HandleMine X Y LastPos
			in
			guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path lastPos:LastPos) = State
			pt(x:X y:Y) = Position
			LabelMine = label(text:"M" handle:HandleMine borderwidth:5 relief:raised bg:ID.color ipadx:5 ipady:5)
			{Grid.grid configure(LabelMine row:X+1 column:Y+1)}
			{HandleMine 'raise'()}
			{Handle 'raise'()}
			guiPlayer(id:ID score:HandleScore submarine:Handle mines:mine(HandleMine Position)|Mine path:Path lastPos:LastPos)
		end
	end

	local
		fun{RmMine Grid Position List}
			case List
			of nil then nil
			[] H|T then
				if (H.2 == Position) then
					{RemoveItem Grid H.1}
					T
				else
					H|{RmMine Grid Position T}
				end
			end
		end

		ExplosionColors = [c(255 255 0) c(255 128 0) c(255 0 0)]
		BorderWidths    = [5 6 7]

		proc{Animation Grid Position State ColorList BorderList}
			case ColorList#BorderList
			of nil#nil then
				skip
			[] (MineColor|T1)#(BorderWidth|T2) then
				ID HandleScore Handle Mine Path LabelMine HandleMine X Y HandleTest LastPos
				in
				guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path lastPos:LastPos) = State
				pt(x:X y:Y) = Position
				LabelMine = label(text:"M" handle:HandleMine borderwidth:BorderWidth relief:raised bg:MineColor ipadx:5 ipady:5)
				{Grid.grid configure(LabelMine row:X+1 column:Y+1)}
				{HandleMine 'raise'()}
				{Handle 'raise'()}
				{Delay 250}
				{Grid.grid forget(HandleMine)}
				{Animation Grid Position State T1 T2}
			end
		end
	in
		fun{RemoveMine Position}
			fun{$ Grid State}
				ID HandleScore Handle Mine Path NewMine LastPos
				in
				guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path lastPos:LastPos) = State
				NewMine = {RmMine Grid Position Mine}
				{Animation Grid Position State ExplosionColors BorderWidths}
				guiPlayer(id:ID score:HandleScore submarine:Handle mines:NewMine path:Path lastPos:LastPos)
			end
		end
	end

	fun{DrawPath Grid Color X Y}
		Handle LabelPath
	in
		LabelPath = label(text:"" handle:Handle bg:Color)
		{Grid.grid configure(LabelPath row:X+1 column:Y+1)}
		Handle
	end

	proc{RemoveItem Grid Handle}
		{Grid.grid forget(Handle)}
	end


	fun{RemovePath Grid State}
		ID HandleScore Handle Mine Path LastPos
	in
		guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path lastPos:LastPos) = State
		for H in Path.2 do
	 	{RemoveItem Grid H}
		end
		guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path.1|nil lastPos:LastPos)
	end

	fun{UpdateLife Life}
		fun{$ Grid State}
			HandleScore
			in
			guiPlayer(id:_ score:HandleScore submarine:_ mines:_ path:_ lastPos:_) = State
			{HandleScore set(Life)}
	 		State
		end
	end


	fun{StateModification Grid WantedID State Fun}
		case State
		of nil then nil
		[] guiPlayer(id:ID score:_ submarine:_ mines:_ path:_ lastPos:_)|Next then
			if (ID == WantedID) then
				{Fun Grid State.1}|Next
			else
				State.1|{StateModification Grid WantedID Next Fun}
			end
		end
	end

	fun{RemovePlayer Grid WantedID State}
		case State
		of nil then nil
		[] guiPlayer(id:ID score:HandleScore submarine:Handle mines:M path:P lastPos:LastPos)|Next then
			{HandleScore set(0)}
			if (ID == WantedID) then
				for H in P do
			 		{RemoveItem Grid H}
				end
				for H in M do
			 		{RemoveItem Grid H.1}
				end
				{RemoveItem Grid Handle}
				Next
			else
				State.1|{RemovePlayer Grid WantedID Next}
			end
		end
	end

	local

		ExplosionColors = [c(255 255 0) c(255 128 0) c(255 0 0)]
		BorderWidths    = [5 6 7]

		proc{GetPath Initial Final ?PtList}
			Dx Dy Max Sx Sy
			proc{Recursive PrevX PrevY RemainX RemainY SignX SignY ?Path}
				NewX NewY Missile
				in
				case RemainX#RemainY
				of 0#0 then
					{Logger debug('end of the created path')}
					Path = nil
				[] 0#Y then
					NewX = PrevX
					NewY = (PrevY + SignY)
					if NewY>PrevY then Missile = Missiles.0 else Missile = Missiles.180 end
					{Logger debug(pt(x:NewX y:NewY))}
					Path = Missile#pt(x:NewX y:NewY)|{Recursive NewX NewY 0 RemainY-1 SignX SignY}
				[] X#0 then
					NewX = (PrevX + SignX)
					NewY = PrevY
					if NewX>PrevX then Missile = Missiles.270 else Missile = Missiles.90 end
					{Logger debug(pt(x:NewX y:NewY))}
					Path = Missile#pt(x:NewX y:NewY)|{Recursive NewX NewY RemainX-1 0 SignX SignY}
				[] X#Y then
					NewX = (PrevX + SignX)
					NewY = (PrevY + SignY)
					if NewX>PrevX andthen NewY>PrevY then
						Missile = Missiles.315
					elseif NewX<PrevX andthen NewY>PrevY then
						Missile = Missiles.45
					elseif NewX>PrevX andthen NewY<PrevY then
						Missile = Missiles.225
					else
						Missile = Missiles.135
					end
					{Logger debug(pt(x:NewX y:NewY))}
					Path = Missile#pt(x:NewX y:NewY)|{Recursive NewX NewY RemainX-1 RemainY-1 SignX SignY}
				end
			end
			in
			Dx = Final.x - Initial.x
			Dy = Final.y - Initial.y
			if Dx<0 then Sx = ~1 else Sx = 1 end
			if Dy<0 then Sy = ~1 else Sy = 1 end
			PtList = {Recursive Initial.x Initial.y {Abs Dx} {Abs Dy} Sx Sy}
		end


		proc{Animation Grid State PositionsList}
			case PositionsList
			of nil then
				skip
			[] Missile#pt(x:X y:Y)|T then
				LabelMissile HandleMissile Handle Color Final
				in
				guiPlayer(id:_ score:_ submarine:Handle mines:_ path:_ lastPos:Final) = State
				if (X==Final.x andthen Y==Final.y) then Color=red else Color=black end
				/* LabelMissile = label(text:"M" handle:HandleMissile borderwidth:5 relief:raised bg:Color ipadx:5 ipady:5) */
				LabelMissile = label(image:Missile handle:HandleMissile)
				{Grid.grid configure(LabelMissile row:X+1 column:Y+1)}
				{HandleMissile 'raise'()}
				{Handle 'raise'()}
				{Delay 200}
				{Grid.grid forget(HandleMissile)}
				{Animation Grid State T}
			end
		end
	in
		fun{DrawExplosion Position}
			fun{$ Grid State}
				ID HandleScore Handle Mine Path NewMine PtPath LastPos
				in
				guiPlayer(id:ID score:HandleScore submarine:Handle mines:Mine path:Path lastPos:LastPos) = State
				PtPath = {GetPath LastPos Position}
				{Animation Grid State PtPath}
				State
			end
		end
	end

	local
		proc{Drawline ID Drone Grid N}
			HandleDrone LabelDrone
			in
			LabelDrone = label(text:"D" handle:HandleDrone borderwidth:5 relief:raised bg:white ipadx:5 ipady:5)
			case Drone
			of drone(row X) then
				if N < Input.nColumn then
					{Grid.grid configure(LabelDrone row:X+1 column:N+1)}
					{HandleDrone 'raise'()}
					{Delay 50}
					{Grid.grid forget(HandleDrone)}
					{Drawline ID Drone Grid N+1}
				end
			[] drone(column Y) then
				if N < Input.nRow then
					{Grid.grid configure(LabelDrone row:N+1 column:Y+1)}
					{HandleDrone 'raise'()}
					{Delay 50}
					{Grid.grid forget(HandleDrone)}
					{Drawline ID Drone Grid N+1}
				end
			else
				skip
			end
		end
	in
		proc{DrawDrone ID Drone Grid}
			{Drawline ID Drone Grid 1}
		end
	end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

	fun{StartWindow}
		Stream
	in
		{NewPort Stream GeneralPort}
		thread
			{TreatStream Stream nil nil}
		end
		GeneralPort
	end

	proc{TreatStream Stream Grid State}
		case Stream
		of nil then skip
		[] buildWindow|T then NewGrid in
			{TreatStream T {BuildWindow} State}
		[] initPlayer(ID Position)|T then NewState in
			NewState = {DrawSubmarine Grid ID Position}
			{TreatStream T Grid NewState|State}
		[] movePlayer(ID Position)|T then
			{TreatStream T Grid {StateModification Grid ID State {MoveSubmarine Position}}}
		[] lifeUpdate(ID Life)|T then
			{TreatStream T Grid {StateModification Grid ID State {UpdateLife Life}}}
			{TreatStream T Grid State}
		[] putMine(ID Position)|T then
			{TreatStream T Grid {StateModification Grid ID State {DrawMine Position}}}
		[] removeMine(ID Position)|T then
			{TreatStream T Grid {StateModification Grid ID State {RemoveMine Position}}}
		[] surface(ID)|T then
			{TreatStream T Grid {StateModification Grid ID State RemovePath}}
		[] removePlayer(ID)|T then
			{TreatStream T Grid {RemovePlayer Grid ID State}}
		[] explosion(ID Position)|T then
			{TreatStream T Grid {StateModification Grid ID State {DrawExplosion Position}}}
		[] drone(ID Drone)|T then
			{DrawDrone ID Drone Grid}
			{TreatStream T Grid State}
		[] sonar(ID)|T then
			{TreatStream T Grid State}
		[] _|T then
			{TreatStream T Grid State}
		end
	end
end
