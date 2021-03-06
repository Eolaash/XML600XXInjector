'Проект "ИнжекторАлгоритма" v004 от 11.01.2022
'
'ОПИСАНИЕ:
' v001 - базовая реализация (для 60090)
' v002 - добавлена возможность чтения 60002; переработан алгоритм чтения алгоритма (появилось понятие RR и OR и дуализм системы расчёта); формулы алгоритма разбиваются на блоки по ТП
' v003 - определяет сторону-эмитент 60002 (если сторона не мы - то инвертировать коэффициенты)
' v004 - исключение чтения 60090 (устарел); преобразование чтения 60002 в автоматический режим при множественных участниках алгоритма

Option Explicit

Const cCurrentVersion = 4
Const cCurrentScript = "ИнжекторАлгоритма"

Dim gScriptFileName, gFSO, gWSO, gScriptPath, gXMLCalcRoute, gXMLBasis, gXMLFilePathA, gXMLFilePathB, gXMLBasisPathLock, gXMLCalcRoutePathLock
Dim gErrorText, gFilesCount, gInjectionsCount, gTotalInjections
Dim gMainDelimiter, gInsideDelimiter


'func 1
Private Function fGetFileExtension(inFileName)
	Dim tPos
	fGetFileExtension = vbNullString
	tPos = InStrRev(inFileName, ".")
	If tPos > 0 Then
		fGetFileExtension = UCase(Right(inFileName, Len(inFileName) - tPos))
	End If
End Function

'func 2
Private Function fGetFileName(inFileName)
	Dim tPos
	fGetFileName = vbNullString
	tPos = InStrRev(inFileName, ".")
	If tPos > 1 Then
		fGetFileName = Left(inFileName, tPos - 1)
	End If
End Function

'func 3
Private Function fGetPeriod(inText, inYear, inMonth)
	Dim tYear, tMonth
	'prep
	fGetPeriod = False
	inYear = 0
	inMonth = 0
	'chk 1
	If Len(inText) <> 6 Then: Exit Function	
	If Not IsNumeric(inText) Then: Exit Function	
	tYear = CInt(Left(inText, 4))
	tMonth = CInt(Right(inText, 2))
	'chk 2
	If tYear < 2000 Or tYear > 2100 Then: Exit Function
	If tMonth < 1 Or tMonth > 12 Then: Exit Function
	'fin
	fGetPeriod = True
	inYear = tYear
	inMonth = tMonth
End Function

'func 4
Private Function fGetTraderID(inText, inTraderID)
	'prep
	fGetTraderID = False
	If Len(inText) <> 8 Then: Exit Function
	'fin
	inTraderID = inText
	fGetTraderID = True
End Function

'func 5
Private Function fGetSubjectID(inText, inSubjectID)
	Dim tSubjectID
	'prep
	fGetSubjectID = False
	If Not IsNumeric(inText) Then: Exit Function
	tSubjectID = CInt(inText)
	If tSubjectID < 1 or tSubjectID > 99 Then: Exit Function
	'fin
	inSubjectID = tSubjectID
	fGetSubjectID = True
End Function

Private Function fXMLCalcRouteConfigCreate(inXMLObject, inDropPath)
	Dim tFilePath, tRoot, tComment, tIntro, tTextFile, tText, tValue
	fXMLCalcRouteConfigCreate = False
	
	'01 // Resolve File Operations
	tFilePath = inDropPath & "\" & "CalcRouteV2.xml"
	WScript.Echo tFilePath
	If gFSO.FileExists(tFilePath) Then
		If gFSO.FileExists(tFilePath & ".bak") Then: Exit Function
		gFSO.MoveFile tFilePath, tFilePath & ".bak"
	End If
	If gFSO.FileExists(tFilePath) Then: Exit Function
	'WScript.Echo "P1 Over"
	
	'02 // RootNode
	Set inXMLObject = CreateObject("Msxml2.DOMDocument.6.0")
	Set tRoot = inXMLObject.CreateElement("message")
	inXMLObject.AppendChild tRoot
	tValue = "CALCROUTE"
	tRoot.SetAttribute "class", tValue
	tValue = "2"
	tRoot.SetAttribute "version", tValue
	tValue = fGetTimeStamp()
	tRoot.SetAttribute "releasestamp", tValue
	
	'03 // Комментарий
    Set tComment = inXMLObject.CreateComment("Сформировано " & Now() & " " & cCurrentScript & " v" & cCurrentVersion)
    inXMLObject.InsertBefore tComment, inXMLObject.ChildNodes(0)
    
    '04 // Processing Instruction
    Set tIntro = inXMLObject.CreateProcessingInstruction("xml", "version='1.0' encoding='Windows-1251' standalone='yes'")
    inXMLObject.InsertBefore tIntro, inXMLObject.ChildNodes(0)
    
    '05 // Save XML
    inXMLObject.Save (tFilePath)
    
    '06 // Реорганизация XML для удобочитаемости в NotePad++
    Set tTextFile = gFSO.OpenTextFile(tFilePath, 1)
    tText = tTextFile.ReadAll
    tTextFile.Close
    Set tTextFile = gFSO.OpenTextFile(tFilePath, 2, True)
    tText = Replace(tText, "><", "> <")
    tTextFile.Write tText
    tTextFile.Close
    
    '07 // Сохранение изменений в XML
    inXMLObject.Load (tFilePath)
    inXMLObject.Save (tFilePath)
	inDropPath = tFilePath
	fXMLCalcRouteConfigCreate = True
End Function

'func 6
Private Function fGetXMLConfig(inPathList, inXMLObject, inFileName, inClassTag)
	Dim tPathList, tLock, tIndex, tFileName, tFilePath, tTempXML, tNode, tValue
	fGetXMLConfig = False
	tPathList = Split(inPathList, ";")
	inPathList = vbNullString
	Set tTempXML = CreateObject("Msxml2.DOMDocument.6.0")
	tTempXML.ASync = False
	tFileName = inFileName
	tIndex = 0
	tLock = False
	'scan
	Do While Not tLock
		If UBound(tPathList) < tIndex Then: Exit Do
		'file path forming
		tFilePath = tPathList(tIndex)
		If Right(tFilePath, 1) <> "\" Then: tFilePath = tFilePath & "\"
		tFilePath = tFilePath & tFileName
		'check if file exist
		'WScript.Echo tFilePath
		If gFSO.FileExists(tFilePath) Then
			tTempXML.Load tFilePath
			If tTempXML.parseError.ErrorCode = 0 Then 'Parsed?
				Set tNode = tTempXML.DocumentElement 'root
                tValue = tNode.NodeName
                If tValue = "message" Then 'message?
					tValue = UCase(tNode.getAttribute("class"))
                    If tValue = inClassTag Then 'message class is inClassTag?
						tValue = tNode.getAttribute("releasestamp")
                        If fCheckTimeStamp(tValue) Then 'release stamp correct?
                            tLock = True							
                        End If
					End If
				End If
			End If
		End If
		tIndex = tIndex + 1
	Loop	
	'fin
	If Not (IsEmpty(tTempXML)) Then: Set tTempXML = Nothing 'release object
	If tLock Then
		'WScript.Echo "LOCK > " & tFilePath
		Set inXMLObject = CreateObject("Msxml2.DOMDocument.6.0")
		inXMLObject.ASync = False
		inXMLObject.Load tFilePath
		inPathList = tFilePath
		fGetXMLConfig = True		
	Else
		'WScript.Echo "Ошибка! XML файл конфигурации " & inClassTag & " не найден!"
	End If	
End Function

'func 7
Private Function fCheckTimeStamp(inValue)
	Dim tValue, tYear, tMonth, tDay
    'PREP
    fCheckTimeStamp = False
    'GET
    If Len(inValue) <> 14 or Not IsNumeric(inValue) Then: Exit Function	
    'sec
    tValue = CInt(Right(inValue, 2))    
    If tValue < 0 Or tValue > 59 Then: Exit Function
    'min
    tValue = CInt(Mid(inValue, 11, 2))    
    If tValue < 0 Or tValue > 59 Then: Exit Function
    'hour
    tValue = CInt(Mid(inValue, 9, 2))    
    If tValue < 0 Or tValue > 24 Then: Exit Function
    'day
    tValue = CInt(Mid(inValue, 7, 2))    
    If tValue < 1 Or tValue > 31 Then: Exit Function
    tDay = tValue
    'month
    tValue = CInt(Mid(inValue, 5, 2))    
    If tValue < 1 Or tValue > 12 Then: Exit Function
    tMonth = tValue
    'year
    tValue = CInt(Left(inValue, 4))
    If tValue < 2010 Or tValue > 2025 Then: Exit Function
    tYear = tValue
    'logic check
    If fDaysPerMonth(tMonth, tYear) < tDay Then: Exit Function
    'over
    fCheckTimeStamp = True
End Function

'func 8
Private Function fDaysPerMonth(inMonth, inYear)
    fDaysPerMonth = 0
    Select Case LCase(inMonth)
        Case "январь", 1:       fDaysPerMonth = 31
        Case "февраль", 2:
            If (inYear Mod 4) = 0 Then
                                fDaysPerMonth = 29
            Else
                                fDaysPerMonth = 28
            End If
        Case "март", 3:         fDaysPerMonth = 31
        Case "апрель", 4:       fDaysPerMonth = 30
        Case "май", 5:          fDaysPerMonth = 31
        Case "июнь", 6:         fDaysPerMonth = 30
        Case "июль", 7:         fDaysPerMonth = 31
        Case "август", 8:       fDaysPerMonth = 31
        Case "сентябрь", 9:     fDaysPerMonth = 30
        Case "октябрь", 10:     fDaysPerMonth = 31
        Case "ноябрь", 11:      fDaysPerMonth = 30
        Case "декабрь", 12:     fDaysPerMonth = 31
    End Select
    If inYear <= 0 Then: fDaysPerMonth = 0
End Function

Private Function fAddZero(inValue)
	fAddZero = inValue
	If IsNumeric(inValue) Then
		If inValue < 10 Then
			fAddZero = "0" & inValue
		End If
	End If
End Function

Private Function fGetTimeStamp()
	Dim tNow
	tNow = Now() '20171017000000	
	fGetTimeStamp = Year(tNow) & fAddZero(Month(tNow)) & fAddZero(Day(tNow)) & fAddZero(Hour(tNow)) & fAddZero(Minute(tNow)) & fAddZero(Second(tNow))
End Function

Private Function fGetTimeStampA()
	Dim tNow
	tNow = Now() '2017-10-17 00:00:00	
	fGetTimeStampA = Year(tNow) & "-" & fAddZero(Month(tNow)) & "-" & fAddZero(Day(tNow)) & " " & fAddZero(Hour(tNow)) & ":" & fAddZero(Minute(tNow)) & ":" & fAddZero(Second(tNow))
End Function

'sub 1
Private Sub fQuit()
	'destroy objects
	Set gFSO = Nothing	
	Set gWSO = Nothing
	Set gXMLBasis = Nothing
	Set gXMLCalcRoute = Nothing
	'quit
	WScript.Quit
End Sub

'XML CONFIG SAVER [UTILITY]
Private Sub fSaveXMLConfigChanges(inFilePath, inXMLObject)
	Dim tNode, tValue, tTextFile, tXMLText, tXMLBufText
	
	' 01 // Config
	Set tNode = inXMLObject.DocumentElement 'root
	tValue = fGetTimeStamp()
	tNode.SetAttribute "releasestamp", tValue
	inXMLObject.Save (inFilePath)
	'p2
	Set tTextFile = gFSO.OpenTextFile(inFilePath, 1)		
	tXMLText = tTextFile.ReadAll	
	tTextFile.Close
	'p3
	Set tTextFile = gFSO.OpenTextFile(inFilePath, 2, True)	
	tXMLText = Replace(tXMLText,"><","> <")
	tTextFile.Write tXMLText
	tTextFile.Close
	'p4
	inXMLObject.Load(inFilePath) 'RESAVE-READ
	inXMLObject.Save(inFilePath) 'RESAVE-SAVE
End Sub

'SELECT VERSION nodes from BASIS by GTP codes
Private Function fSelectSectionVersion(inXMLBasis, inIsComplex, inGTPFrom, inGTPTo, inTraderFrom, inTraderTo, outVersionNodeA, outVersionNodeB, outErrorText)
	Dim tBSectionNode, tBVersionCount, tBVersionNodes, tSelectedVersion, tVersionLock, tIndex, tTextList, tValue, tNode, tXPathString
	Dim tBVersionList()
	Dim tBVersionStatus()
	' 00 // prepare
	fSelectSectionVersion = False
	outErrorText = vbNullString
	Set outVersionNodeA = Nothing 'out version node MAIN
	Set outVersionNodeB = Nothing 'out version node LINKED (oprional)
	
	' 01 // Lock SECTION_A node
	tXPathString = "//trader[@id='" & inTraderFrom & "']/gtp[@id='" & inGTPFrom & "']/section[@id='" & inGTPTo & "']"
	Set tBSectionNode = inXMLBasis.SelectNodes(tXPathString)
	If tBSectionNode.Length <> 1 Then
		outErrorText = "Не удалось определить наличие перетока " & inGTPFrom & "-" & inGTPTo & " в BASIS! Найдено - " & tBSectionNode.Length & "."
		Exit Function
	End If
	Set tBSectionNode = tBSectionNode(0)
	
	' 02 // Get VERSIONs of A_Section
	tBVersionCount = -1
	tXPathString = "child::version"
	Set tBVersionNodes = tBSectionNode.SelectNodes(tXPathString)	
	If tBVersionNodes.Length = 0 Then
		outErrorText = "Не удалось определить ни одну версию перетока " & inGTPFrom & "-" & inGTPTo & " в BASIS!"		
		Exit Function
	End If
	
	' 03  // Read version LIST of A_Section
	tSelectedVersion = -1
	For Each tNode in tBVersionNodes
		tBVersionCount = tBVersionCount + 1
		ReDim Preserve tBVersionList(tBVersionCount)
		ReDim Preserve tBVersionStatus(tBVersionCount)
		tBVersionList(tBVersionCount) = tNode.getAttribute("id")
		tBVersionStatus(tBVersionCount) = tNode.getAttribute("status")
		tSelectedVersion = tBVersionList(tBVersionCount)
	Next
	
	' 04 // Form list string
	tTextList = vbNullString
	For tIndex = 0 To tBVersionCount
		If tTextList = vbNullString Then
			tTextList = tBVersionList(tIndex) & " (" & tBVersionStatus(tIndex) & ")"
		Else
			tTextList = tTextList & vbCrLf & tBVersionList(tIndex) & " (" & tBVersionStatus(tIndex) & ")"
		End If
	Next	
	
	' 05 // ASK OPERATOR to SELECT VERSION
	tSelectedVersion = InputBox("Выберите версию перетока " & inGTPFrom & "-" & inGTPTo & " >>> " & vbCrLf & tTextList, "Задайте номер версии из списка", tSelectedVersion)
	If Not(IsNumeric(tSelectedVersion)) Then
		outErrorText = "Необходимо выбирать варианты из списка и только!"
		Exit Function
	Else
		tVersionLock = False
		For Each tValue In tBVersionList
			If CInt(tValue) = CInt(tSelectedVersion) Then
				tVersionLock = True
				Exit For
			End If
		Next
		If Not tVersionLock Then
			outErrorText = "Необходимо выбирать варианты из списка и только!"
			Exit Function
		End If
	End If
	
	' 06 // Over
	If tVersionLock Then
		
		'A_Section by tSelectedVersion
		tXPathString = "//trader[@id='" & inTraderFrom & "']/gtp[@id='" & inGTPFrom & "']/section[@id='" & inGTPTo & "']/version[@id='" & tSelectedVersion & "']"
		'WScript.Echo "NodeA = " & tXPathString
		Set outVersionNodeA = inXMLBasis.SelectSingleNode(tXPathString)
		If outVersionNodeA Is Nothing Then
			outErrorText = "Не удалось выбрать версию " & tSelectedVersion & " перетока " & inGTPFrom & "-" & inGTPTo & "!"
			Exit Function
		End If
		
		'B_Section by tSelectedVersion LINK
		If inIsComplex Then
			tXPathString = "//trader[@id='" & inTraderTo & "']/gtp[@id='" & inGTPTo & "']/section[@id='" & inGTPFrom & "']/version[@id='" & tSelectedVersion & "']"		
			Set outVersionNodeB = inXMLBasis.SelectSingleNode(tXPathString)
			If outVersionNodeB Is Nothing Then
				outErrorText = "Не обнаружена смежная версия " & tSelectedVersion & " перетока " & inGTPFrom & "-" & inGTPTo & "! В BASIS необходимо внести обе стороны!"
				Exit Function
			End If
		End If
		
		fSelectSectionVersion = True
	End If
End Function

Private Sub fGetMPointCodesByChannelID(inLinkNode, inChannelID, outMPCode, outMPChannelCode)
	Dim tNode, tXPathString
	
	tXPathString = "ancestor::body/descendant::dictionaries/measuring-points/measuring-point/measuring-device/measuring-channel[@id-measuring-channel='" & inChannelID & "']"
	Set tNode = inLinkNode.SelectSingleNode(tXPathString)
	If tNode Is Nothing Then
		WScript.Echo "Node not found!" & vbCrLf & vbCrLf & tXPathString
		fQuit
	End If
	
	'###EXAMPLE###
	'<measuring-point id-measuring-point="4" ats-code="702080018318201" guid="6cac98c1-b986-4f67-ab12-05475400c760" id-gtp="1" id-power-object="2" is-pseudo-measurement="false" odu-so="" schemanum="4" measuring-point-type="general" point-voltage="400">
	'	<name power-object-name="ПС 35 кВ Мохтиковская" connection-name="ввод 0,4 кВ ТСН-2" location-description=""/>
	'	<measuring-device id-measuring-device="4" ats-code="01" guid="9d969184-e15f-4a13-8b5f-286cb288b47e" is-for-coding="true" so-device-modification-name="" serial-number="" id-device-modification="2" precision-class-active="0.2S" precision-class-reactive="0.5">
	'		<measuring-channel id-measuring-channel="13" ats-code="01"/>
	
	outMPCode = tNode.ParentNode.ParentNode.getAttribute("ats-code") 'UP 2 levels to <measuring-point>
	outMPChannelCode = tNode.getAttribute("ats-code")
	Set tNode = Nothing
End Sub

Private Function fAddElement(inBase, inElement)
	If inBase = vbNullString Then
		inBase = inElement
	Else
		inBase = inBase & gMainDelimiter & inElement
	End If
End Function

'CALCFORMULA OperationChecker [UTILITY]
Private Function fOperationCheck(inNode, outFormula, inOperation, inParamCount, inParam1Name, inParam2Name, inParam3Name)
	Dim tNode, tValue, tParamName, tParamNode, tParam1OK, tParam2OK, tParam3OK
	
	' 01 // Prepare
	fOperationCheck = False
	tValue = 0
	
	' 02 // Param checks
	Set tNode = inNode.SelectNodes("child::param")
	
	' 02.01 // Count check
	If tNode.Length <> inParamCount Then
		outFormula = "#EO1-" & inOperation & "#"
		Exit Function
	End If
	
	' 02.02 // Param name scan	
	tParam1OK = (inParam1Name = vbNullString)
	tParam2OK = (inParam2Name = vbNullString)
	tParam3OK = (inParam3Name = vbNullString)
		
	For Each tParamNode In tNode
		tParamName = tParamNode.getAttribute("name")
		If Not IsNull(tParamName) Then
			If tParamName = inParam1Name Then
				tParam1OK = True
			ElseIf tParamName = inParam2Name Then
				tParam2OK = True
			ElseIf tParamName = inParam3Name Then
				tParam3OK = True
			End If
		End If
	Next
	
	If Not (tParam1OK And tParam2OK And tParam3OK) Then 'if paramnames not found in param set
		outFormula = "#EO3-" & inOperation & "#"
		Exit Function
	End If
	
	' 03 // Succesful check
	fOperationCheck = True
End Function

'CALCFORMULA Node formula reader
Private Function fGetOperationFormula(inNode, inClass, inVersion)
	Dim tOperation, tOperator, tParam1Name, tParam2Name, tParam3Name, tParamCount, tParamNode
		
	' 01 // Get OPERATION
	fGetOperationFormula = vbNullString
	tOperation = inNode.GetAttribute("name")
	tParam1Name = vbNullString
	tParam2Name = vbNullString
	tParam3Name = vbNullString
	tOperator = "#!!!#"
	tParamCount = 0
	Set tParamNode = Nothing
	
	' 02 // OPERATION Selector
	Select Case tOperation		
		' 02.01 // SUM Operators
		Case "SUM1":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "Wb"
			tOperator = "+"
		Case "SUM2":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "C"
			tOperator = "+"
		Case "SUB1":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "Wb"
			tOperator = "-"
		Case "SUB2":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "C"
			tOperator = "-"
		Case "MULT1":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "Wb"
			tOperator = "*"
		Case "MULT2":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "C"
			tOperator = "*"
		Case "DIV1":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "C"
			tOperator = "/"
		Case "INV1":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "C"
			tOperator = "^"
		Case "INV2":
			tParamCount = 2
			tParam1Name = "C1"
			tParam2Name = "C2"
			tOperator = "^"			
		Case "USL1": 
			tParamCount = 3
			tParam1Name = "WR1"
			tParam2Name = "Wa"
			tParam3Name = "Wb"
			tOperator = "?"
		Case "USL2": 
			tParamCount = 3
			tParam1Name = "WR1"
			tParam2Name = "Wa"
			tParam3Name = "C"
			tOperator = "?"
		Case "EQU1":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "C"
			tOperator = "="
		Case "BOL1":
			tParamCount = 2
			tParam1Name = "Wa"
			tParam2Name = "C"
			tOperator = ">"
		Case "LOGAND":
			tParamCount = 2
			tParam1Name = "WR1"
			tParam2Name = "WR2"
			tOperator = "AND"
		Case "Константа":
			tParamCount = 1
			tParam1Name = "const"			
			tOperator = vbNullString
		Case Else:
			fGetOperationFormula = "#EO4-" & tOperation & "#"
			Exit Function
	End Select
		
	' 03 // OPERATION Consists check
	If Not fOperationCheck(inNode, fGetOperationFormula, tOperation, tParamCount, tParam1Name, tParam2Name, tParam3Name) Then: Exit Function
	
	' 04 // OPERAND (PARAM) Formula extraction
	' 04.01 // OPERAND #1
	If tParam1Name <> vbNullString Then
		Set tParamNode = inNode.SelectSingleNode("child::param[@name='" & tParam1Name & "']")
		fAddElement fGetOperationFormula, fReprocessNodeFormula(tParamNode, inClass, inVersion)
	End If
	
	' 04.01 // OPERAND #2
	If tParam2Name <> vbNullString Then
		Set tParamNode = inNode.SelectSingleNode("child::param[@name='" & tParam2Name & "']")
		fAddElement fGetOperationFormula, fReprocessNodeFormula(tParamNode, inClass, inVersion)
	End If
	
	' 04.01 // OPERAND #3
	If tParam3Name <> vbNullString Then
		Set tParamNode = inNode.SelectSingleNode("child::param[@name='" & tParam3Name & "']")
		fAddElement fGetOperationFormula, fReprocessNodeFormula(tParamNode, inClass, inVersion)
	End If
	
	' 05 // OPERATOR Finalyzer
	If tOperator <> vbNullString Then: fAddElement fGetOperationFormula, tOperator
End Function

'CALCSUM Node formula reader
Private Function fGetCalcSumFormula(inNode, inClass, inVersion)
	Dim tSumElementNode, tSumElement, tSumIndex
	Dim tMPointCode, tMPointChannel, tMPointCoefficient
	
	' 01 // Prepare
	fGetCalcSumFormula = vbNullString
	tSumIndex = 0
	
	' 02 // Should be nonzero childs
	If inNode.ChildNodes.Length = 0 Then
		fGetCalcSumFormula = "#ECS1#"
		Exit Function
	End If
	
	' 03 // Scan for childs
	For Each tSumElementNode In inNode.ChildNodes
		tSumElement = vbNullString
		
		' 03.01 // Element selector
		Select Case tSumElementNode.NodeName
			
			' 03.01.01 // MP Type [60090]			// <measuringchannel mpcode="722080092108101" code="02" coefficient="1"/>
			Case "measuringchannel":
				If inClass = "60090" And (inVersion = "1" Or inVersion = "2") Then
					tSumIndex = tSumIndex + 1
					tSumElement = "MPC"
					tMPointCode = tSumElementNode.GetAttribute("mpcode")
					tMPointChannel = tSumElementNode.GetAttribute("code")
					tMPointCoefficient = tSumElementNode.GetAttribute("coefficient")
					tSumElement = tSumElement & gInsideDelimiter & tMPointCode & gInsideDelimiter & tMPointChannel
					If tMPointCoefficient <> 1 Then 'COEF = ONE(1) - no changes needed [OPTIMIZED]
						fAddElement tSumElement, tMPointCoefficient
						fAddElement tSumElement, "*"
					End If
				Else
					fGetCalcSumFormula = "#ECS3#"
					Exit Function
				End If
			
			' 03.01.02 // MP Type [60002]			 // <measuring-channel id-measuring-channel="1" coefficient="1"/>
			Case "measuring-channel":
				If inClass = "60002" And inVersion Then
					tSumIndex = tSumIndex + 1
					tSumElement = "MPC"
					
					fGetMPointCodesByChannelID tSumElementNode, tSumElementNode.GetAttribute("id-measuring-channel"), tMPointCode, tMPointChannel					
					
					tMPointCoefficient = tSumElementNode.GetAttribute("coefficient")					
					tSumElement = tSumElement & gInsideDelimiter & tMPointCode & gInsideDelimiter & tMPointChannel
					If tMPointCoefficient <> 1 Then 'COEF = ONE(1) - no changes needed [OPTIMIZED]
						fAddElement tSumElement, tMPointCoefficient
						fAddElement tSumElement, "*"
					End If
				Else
					fGetCalcSumFormula = "#ECS4#"
					Exit Function
				End If
				
			' 03.01.03 // Else type			
			Case Else:
				fGetCalcSumFormula = "#ECS2#"
				Exit Function
		End Select
				
		' 03.02 // Finalyzer
		fAddElement fGetCalcSumFormula, tSumElement
		If tSumIndex > 1 Then: fAddElement fGetCalcSumFormula, "+" 'if u have more than one element - using SUM operator
	Next
	
	'finisher
	'If tSumIndex = 1 Then 
		'fAddElement tResultFormula, 0
		'fAddElement tResultFormula, "+"
	'End If
End Function

'MAIN FORMULA REPROCESSOR (60090/60002 FORMULA READER)
Private Function fReprocessNodeFormula(inNode, inClass, inVersion)
	Dim tOperationNode, tNodeType
	
	' 01 \\ Prepare data
	fReprocessNodeFormula = vbNullString	
	
	' 02 \\ Check logic
	If inNode.ChildNodes.Length <> 1 Then
		fReprocessNodeFormula = "#E00#" 'statament error
		Exit Function
	End If
	
	' 03 \\ Get OPERATION node
	Set tOperationNode = inNode.ChildNodes(0)
	tNodeType = tOperationNode.NodeName
	
	' 04 \\ Select OPERATION by node name
	Select Case tNodeType	
		' 04.01 \\ Operation CALCFORMULA 
		Case "calcformula":	
			fReprocessNodeFormula = fGetOperationFormula(tOperationNode, inClass, inVersion)			
			
		' 04.02 \\ Operation CONSTVALUE
		Case "constvalue":
			fReprocessNodeFormula = tOperationNode.Text
			
		' 04.03 \\ Operation CALCSUM
		Case "calcsum":
			fReprocessNodeFormula = fGetCalcSumFormula(tOperationNode, inClass, inVersion)
		Case Else
			fReprocessNodeFormula = "#E01[" & tNodeType & "]#" 'unknown operation
			Exit Function
	End Select
	'get params
End Function

Private Function fGetFormula(inOperator, inArgumentA, inArgumentB)
	fGetFormula = vbNullString
	fGetFormula = inArgumentA & gMainDelimiter & inArgumentB & gMainDelimiter & inOperator
End Function

Private Function fGetDirectionCoefficient(inNode)
	Dim tValue
	fGetDirectionCoefficient = 0
	If inNode Is Nothing Then: Exit Function
	If inNode.ChildNodes.Length <> 1 Then: Exit Function	
	tValue = inNode.ChildNodes(0).GetAttribute("losses-coefficient")
	If IsNumeric(tValue) Then
		tValue = CInt(tValue)
		If (tValue = 1) Or (tValue = -1) Then
			fGetDirectionCoefficient = tValue
		End If
	End If
End Function

Private Function fGetCalcRouteNode(inXMLCalcRoute, inBVersionNode, outCRNode)
	Dim tAIISCode, tGTPID, tSectionID, tSectionVersion, tNode, tXPathMainString, tXPathString, tTraderINN, tTraderID, tTraderName, tCRNode
	' 00 // Prepare
	fGetCalcRouteNode = False
	Set outCRNode = Nothing
	' 01 // Gather data
	tSectionVersion = inBVersionNode.getAttribute("id")
	'section node
	Set tNode = inBVersionNode.ParentNode
	tSectionID = tNode.getAttribute("id")
	'gtp node
	Set tNode = tNode.ParentNode
	tGTPID = tNode.getAttribute("id")
	tAIISCode = tNode.getAttribute("aiiscode")	
	'trader node
	Set tNode = tNode.ParentNode
	tTraderINN = tNode.getAttribute("inn")
	tTraderID = tNode.getAttribute("id")
	tTraderName = tNode.getAttribute("name")
	' 02 // Main XPath
	tXPathMainString = "//trader[@inn='" & tTraderINN & "']/gtp[@aiiscode='" & tAIISCode & "']/section[@id='" & tSectionID & "']/version[@id='" & tSectionVersion & "']"
	Set tCRNode = inXMLCalcRoute.SelectSingleNode(tXPathMainString)
	' 03 // Rebuild structure if not found
	If tCRNode Is Nothing Then
		' LV 1 // TRADER inject
		tXPathString = "//trader[@inn='" & tTraderINN & "']"
		Set tCRNode = inXMLCalcRoute.SelectSingleNode(tXPathString)
		If tCRNode Is Nothing Then
			Set tCRNode = inXMLCalcRoute.DocumentElement 'ROOT
			Set tCRNode = tCRNode.AppendChild(inXMLCalcRoute.CreateElement("trader"))
			tCRNode.SetAttribute "id", tTraderID
			tCRNode.SetAttribute "name", tTraderName
			tCRNode.SetAttribute "inn", tTraderINN
		End If
		Set tNode = tCRNode
		' LV 2 // GTP inject
		tXPathString = tXPathString & "/gtp[@aiiscode='" & tAIISCode & "']"
		Set tCRNode = inXMLCalcRoute.SelectSingleNode(tXPathString)
		If tCRNode Is Nothing Then			
			If tNode Is Nothing Then
				WScript.Echo "ANOMALY! [inject GTP]"
				Exit Function
			End If
			Set tCRNode = tNode.AppendChild(inXMLCalcRoute.CreateElement("gtp"))
			tCRNode.SetAttribute "id", tGTPID
			tCRNode.SetAttribute "aiiscode", tAIISCode
		End If
		Set tNode = tCRNode
		' LV 3 // SECTION inject
		tXPathString = tXPathString & "/section[@id='" & tSectionID & "']"
		Set tCRNode = inXMLCalcRoute.SelectSingleNode(tXPathString)
		If tCRNode Is Nothing Then			
			If tNode Is Nothing Then
				WScript.Echo "ANOMALY! [inject SECTION]"
				Exit Function
			End If
			Set tCRNode = tNode.AppendChild(inXMLCalcRoute.CreateElement("section"))
			tCRNode.SetAttribute "id", tSectionID
		End If
		Set tNode = tCRNode
		' LV 4 // VERSION inject
		tXPathString = tXPathString & "/version[@id='" & tSectionVersion & "']"
		Set tCRNode = inXMLCalcRoute.SelectSingleNode(tXPathString)
		If tCRNode Is Nothing Then			
			If tNode Is Nothing Then
				WScript.Echo "ANOMALY! [inject VERSION]"
				Exit Function
			End If
			Set tCRNode = tNode.AppendChild(inXMLCalcRoute.CreateElement("version"))
			tCRNode.SetAttribute "id", tSectionVersion
		End If
	End If
	' 04 // Over
	fGetCalcRouteNode = True
	Set outCRNode = tCRNode
End Function

'MAIN FORMULA EXTRACTOR (V3)
Private Function fMainFormulaExtractor(inFormulaNode, inClass, inVersion, outFormula, outLossesCoefficient, outErrorText)
	Dim tFuncName, tFormulaNode, tTempValue, tErrorText
	
	' 01 // Prepare
	fMainFormulaExtractor = False
	outFormula = vbNullString
	outLossesCoefficient = 0
	outErrorText = vbNullString
	tErrorText = vbNullString
	tFuncName = "MainFEx"
	
	' 02 // Check
	If inFormulaNode Is Nothing Then
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода не инициализирована!")
		Exit Function
	End If
	
	If inFormulaNode.ChildNodes.Length <> 1 Then
		outErrorText = fGetWarnText(1, tFuncName, "Дочерних нод должно быть 1!")
		Exit Function
	End If
	
	' 03 // Select formula node (child of main node)
	Set tFormulaNode = inFormulaNode.FirstChild
	
	' 04 // Node type selector
	Select Case tFormulaNode.NodeName
		'NORMAL
		Case "calcsum":
			tTempValue = tFormulaNode.GetAttribute("losses-coefficient")
			If Not IsNull(tTempValue) Then
				If IsNumeric(tTempValue) Then
					outLossesCoefficient = CDbl(tTempValue)
				Else
					outErrorText = fGetWarnText(1, tFuncName, "Error! losses-coefficient unexpected [" & tTempValue & "]!")
					Exit Function
				End If
			End If
			Set tFormulaNode = inFormulaNode
		'COMPLEX
		Case "ratio-converter":
			Set tFormulaNode = inFormulaNode.FirstChild
		'UNKNOWN
		Case Else:
			Set tFormulaNode = Nothing
			outErrorText = fGetWarnText(1, tFuncName, "Error! Child name unexpected [" & tFormulaNode.NodeName & "]!")
			Exit Function
	End Select	
	
	' 05 // Checking result
	If tFormulaNode Is Nothing Then 
		outErrorText = fGetWarnText(1, tFuncName, "Не удалось определить начальную ноду формулы!")
		Exit Function
	End If
	
	' 06 // Extracting formula
	outFormula = fReprocessNodeFormula(tFormulaNode, inClass, inVersion)
	If InStr(outFormula, "#E") > 0 Then
		outErrorText = fGetWarnText(1, tFuncName, "Ошибка извлечения формулы!" & vbCrLf & outFormula) 'outFormula
		Exit Function
	End If
		
	' 07 // Extraction succesful
	fMainFormulaExtractor = True
End Function

'LOSSES FORMULA EXTRACTOR (V3)
Private Function fLossesFormulaExtractor(inFormulaNode, inClass, inVersion, outFormula, inLossesCoefficient, outErrorText)
	Dim tFuncName
	
	' 01 // Prepare
	fLossesFormulaExtractor = False
	outFormula = vbNullString	
	outErrorText = vbNullString	
	tFuncName = "LossesFEx"	

	' 02 // Checking result
	If inFormulaNode Is Nothing Then 
		outErrorText = fGetWarnText(1, tFuncName, "Не удалось определить начальную ноду формулы!")
		Exit Function
	End If
	
	' 03 // Extracting formula
	outFormula = fReprocessNodeFormula(inFormulaNode, inClass, inVersion)
	If InStr(outFormula, "#E") > 0 Then
		outErrorText = fGetWarnText(1, tFuncName, "Ошибка извлечения формулы!" & vbCrLf & outFormula) 'outFormula
		Exit Function
	End If
	
	' 04 // Losses coefficient assign
	If inLossesCoefficient <> 1 Then 'if COEF is ONE(1) mean no change for value [OPTIMIZED]
		fAddElement outFormula, inLossesCoefficient
		fAddElement outFormula, "*"
	End If
		
	' 05 // Extraction succesful
	fLossesFormulaExtractor = True
End Function

'WARN FORMER
Private Function fGetWarnText(inLevel, inSubName, inErrorText)
	Dim tLevelText
	Select Case inLevel
		Case 0: tLevelText = "WARN"
		Case 1: tLevelText = "CRIT"
		Case Else: tLevelText = "WARN"
	End Select
	fGetWarnText = "[" & tLevelText & "] " & inSubName & ": " & inErrorText
End Function

'EASY LOGGER
Private Sub fDropTextToFile(inText, inFileName)
	Dim tTextFile
	Set tTextFile = gFSO.OpenTextFile(gScriptPath & "\" & inFileName & ".txt", 2, True)
	tTextFile.WriteLine inText
	tTextFile.Close
End Sub

Private Function fExtractPointDirectionNode(inNode, inClass, inVersion, outTPName, outTPMethod, outTPID, outTPAIISCode, outTPTraderID, outTPDirection, outTPCoefficient, outTPMainFormula, outTPLossesFormula, outErrorText)
	Dim tFuncName, tFormulaNode, tXPathString, tMainFormulaNode, tLossesFormulaNode, tIndex, tTPLossesCoefficient, tMainFormula, tLossesFormula, tErrorText, tTempText, tNode

	'EXAMPLE: <rr id-tp-aup="0005" send-receive="receive" aiiscode="5600004800" trader-code="BELKAMKO" coefficient="-1"/>
	' 01 \\ Prepare data
	fExtractPointDirectionNode = False
	tFuncName = "ExPDN"
	outErrorText = vbNullString
	outTPMainFormula = vbNullString		'MAIN
	outTPLossesFormula = vbNullString	'LOSSES
	outTPName = vbNullString
	outTPMethod = vbNullString
	outTPID = 0
	outTPAIISCode = vbNullString
	outTPTraderID  = vbNullString
	outTPDirection  = vbNullString
	outTPCoefficient = 0
	Set tMainFormulaNode = Nothing
	Set tLossesFormulaNode = Nothing
	tTPLossesCoefficient = 0
	tMainFormula = vbNullString
	tLossesFormula = vbNullString
	
	' 02 \\ Checks
	' 02.01 \\ IS NODE OK?
	If inNode Is Nothing Then
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода не инициализирована!")
		Exit Function
	End If
	
	' 02.01 \\ NodeName check
	outTPMethod = inNode.NodeName
	If Not (outTPMethod = "rr" Or outTPMethod = "or") Then
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода имеет имя <" & outTPMethod & ">, когда должно быть <rr> или <or>!")
		Exit Function
	End If
	
	' 03 \\ Attributes extraction
	outTPName = inNode.ParentNode.getAttribute("name")
	outTPCoefficient = inNode.getAttribute("coefficient")
	outTPDirection  = inNode.getAttribute("send-receive")
	
	'class defined
	If inClass = "60090" Then		'<or id-tp-aup="0003" send-receive="send" aiiscode="8600004700" trader-code="BELKAMKO" coefficient="1"/>
		Select Case inVersion
			Case "1", "2":
				outTPID = inNode.getAttribute("id-tp-aup")
				outTPAIISCode = inNode.getAttribute("aiiscode")
				outTPTraderID  = inNode.getAttribute("trader-code")				
		End Select
	ElseIf inClass = "60002" Then	'<or id-delivery-point="3" send-receive="receive" id-aiis="1" id-org="1" coefficient="-1"/>
		Select Case inVersion
			Case "1":
				outTPID = inNode.getAttribute("id-delivery-point")
				outTPAIISCode = inNode.getAttribute("id-aiis")
				outTPTraderID  = inNode.getAttribute("id-org")				
		End Select
	End If
	
	' 04 \\ Checks
	' 04.01 \\ Coef
	If Not IsNumeric(outTPCoefficient) Then	
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода <" & outTPName & "/" & outTPMethod & "> имеет нецифровое значение @coefficient = <" & outTPCoefficient & "> (допустимо -1 или 1)!")		
		Exit Function
	End If
	
	outTPCoefficient = CInt(outTPCoefficient)
	
	If Abs(outTPCoefficient) <> 1 Then
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода <" & outTPName & "/" & outTPMethod & "> имеет неверное значение @coefficient = <" & outTPCoefficient & "> (допустимо -1 или 1)!")
		Exit Function
	End If
	
	' 04.02 \\ Direction
	If Not (outTPDirection = "send" Or outTPDirection = "receive") Then
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода <" & outTPName & "/" & outTPMethod & "> имеет неверное значение @send-receive = <" & outTPDirection & "> (допустимо ""send"" или ""recieve"")!")
		Exit Function
	End If
	
	' EXAMPLE - <aup-deliverypoint id-tp-aup="0001" aiiscode="5600004800" trader-code="BELKAMKO">
	' 05 \\ Locking formula node	
	' 05.01 \\ Main search	
	If inClass = "60002" Then
		Select Case inVersion
			Case "1":
				tTempText = "<aup-delivery-point>"
				tXPathString = "ancestor::algorithm/descendant::aup-delivery-points/aup-delivery-point[(@id-delivery-point='" & outTPID & "' and @id-aiis='" & outTPAIISCode & "' and @id-org='" & outTPTraderID & "')]/*[contains(name(),'" & outTPDirection & "')]"
		End Select
	Else
		outErrorText = fGetWarnText(1, tFuncName, "Неожиданный класс XML-объекта (inClass=" & inClass & ")!")
		Exit Function
	End If
		
	Set tFormulaNode = inNode.SelectNodes(tXPathString)
	If tFormulaNode.Length = 0 Then
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода <" & outTPName & "/" & outTPMethod & "> не нашла себе ноды " & tTempText & " для извлечения формулы!" & vbCrLf & "XPath > " & tXPathString)
		Exit Function
	End If
	
	' 05.02 \\ Node assigning
	For tIndex = 0 To tFormulaNode.Length - 1
		If tFormulaNode(tIndex).NodeName = outTPDirection Then 'if NODENAME is equal DIRECTION - mean main formula (else <DIRECTION-losses> NODENAME - mean losses formula) \\ easy splitter
			Set tMainFormulaNode = tFormulaNode(tIndex)	'main node
		Else
			Set tLossesFormulaNode = tFormulaNode(tIndex) 'losses node
		End If
	Next
	
	' 06 \\ Formula extraction
	If tMainFormulaNode Is Nothing Then
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода <" & outTPName & "/" & outTPMethod & "> не нашла себе ноды <aup-deliverypoint> для извлечения формулы! tMainFormulaNode = Nothing")
		Exit Function
	End If
	
	' 06.02 \\ MAIN Formula + LOSSES Coef extraction
	If Not fMainFormulaExtractor(tMainFormulaNode, inClass, inVersion, tMainFormula, tTPLossesCoefficient, tErrorText) Then
		outErrorText = fGetWarnText(1, tFuncName, "Входная нода <" & outTPName & "/" & outTPMethod & ">! Ошибка извлечения основной формулы!" & vbCrLf & tErrorText)
		Exit Function
	End If
	
	'to OUT
	outTPMainFormula = tMainFormula
	
	' 06.03 \\ LOSSES Formula (with COEF modification!)
	If Not tLossesFormulaNode Is Nothing Then 
		If Not fLossesFormulaExtractor(tLossesFormulaNode, inClass, inVersion, tLossesFormula, tTPLossesCoefficient, tErrorText) Then
			outErrorText = fGetWarnText(1, tFuncName, "Входная нода <" & outTPName & "/" & outTPMethod & ">! Ошибка извлечения формулы потерь!" & vbCrLf & tErrorText)
			Exit Function
		End If
		
		'to OUT
		outTPLossesFormula = tLossesFormula
	End If
	
	' 07 \\ Convertation issues
	If inClass = "60002" Then	'<or id-delivery-point="3" send-receive="receive" id-aiis="1" id-org="1" coefficient="-1"/>
		Select Case inVersion
			Case "1":				
				'outTPID = inNode.getAttribute("id-delivery-point")
				
				'AIIS resolver
				tXPathString = "ancestor::body/descendant::dictionaries/aiises/aiis[@id-aiis='" & outTPAIISCode & "']"
				Set tNode = inNode.SelectSingleNode(tXPathString)
				outTPAIISCode = tNode.getAttribute("ats-code")
				
				'TRADER resolver
				tXPathString = "ancestor::body/descendant::dictionaries/organizations/organization[@id-org='" & outTPTraderID & "']"
				Set tNode = inNode.SelectSingleNode(tXPathString)
				outTPTraderID  = tNode.getAttribute("trader-code")		

				Set tNode = Nothing
		End Select
	End If
	
	'tTempText = "LOCK=" & tFormulaNode.Length & " MAINNODE=" & tMainFormulaNode.NodeName & vbCrLf & vbCrLf & tMainFormula & vbCrLf & vbCrLf & tLossesFormula
	'WScript.Echo tTempText
	'fDropTextToFile tTempText, "Log"
	'WScript.Quit
	
	' 07 \\ Succesful
	fExtractPointDirectionNode = True	
End Function

Private Function fCalcRouteNodeCreate(inVersionNode, inXMLCalcRoute, inSourceFileName)
	Dim tVNode, tCNode, tRNode, tXPathString
	
	' 01 // Prepare
	Set fCalcRouteNodeCreate = Nothing
	
	' 02 // TRADER Node
	Set tRNode = inXMLCalcRoute.DocumentElement	
	Set tVNode = inVersionNode.SelectSingleNode("ancestor::trader")
	tXPathString = "//trader[@id='" & tVNode.getAttribute("id") & "']"
	Set tCNode =  inXMLCalcRoute.SelectSingleNode(tXPathString)
	If tCNode Is Nothing Then
		Set tCNode = tRNode.AppendChild(inXMLCalcRoute.CreateElement("trader"))
		tCNode.SetAttribute "id", tVNode.getAttribute("id")
		tCNode.SetAttribute "name", tVNode.getAttribute("name")
		tCNode.SetAttribute "inn", tVNode.getAttribute("inn")
	End If
	
	' 03 // GTP Node
	Set tRNode = tCNode
	Set tVNode = inVersionNode.SelectSingleNode("ancestor::gtp")
	tXPathString = tXPathString & "/gtp[@id='" & tVNode.getAttribute("id") & "']"
	Set tCNode =  inXMLCalcRoute.SelectSingleNode(tXPathString)
	If tCNode Is Nothing Then
		Set tCNode = tRNode.AppendChild(inXMLCalcRoute.CreateElement("gtp"))
		tCNode.SetAttribute "id", tVNode.getAttribute("id")
		tCNode.SetAttribute "aiiscode", tVNode.getAttribute("aiiscode")
	End If
	
	' 04 // SECTION Node
	Set tRNode = tCNode
	Set tVNode = inVersionNode.SelectSingleNode("ancestor::section")
	tXPathString = tXPathString & "/section[@id='" & tVNode.getAttribute("id") & "']"
	Set tCNode =  inXMLCalcRoute.SelectSingleNode(tXPathString)
	If tCNode Is Nothing Then
		Set tCNode = tRNode.AppendChild(inXMLCalcRoute.CreateElement("section"))
		tCNode.SetAttribute "id", tVNode.getAttribute("id")
	End If
	
	' 05 // VERSION Node
	Set tRNode = tCNode
	Set tVNode = inVersionNode
	tXPathString = tXPathString & "/version[@id='" & tVNode.getAttribute("id") & "']"
	Set tCNode =  inXMLCalcRoute.SelectSingleNode(tXPathString)
	If tCNode Is Nothing Then
		Set tCNode = tRNode.AppendChild(inXMLCalcRoute.CreateElement("version"))
		tCNode.SetAttribute "id", tVNode.getAttribute("id")
		tCNode.SetAttribute "comment", inSourceFileName
	End If
	
	' 06 // Over
	Set fCalcRouteNodeCreate = tCNode
	Set tRNode = Nothing
	Set tVNode = Nothing
	Set tCNode = Nothing
End Function

Private Function fCalcRoutePrepare(inVersionNodeA, inVersionNodeB, inXMLCalcRoute, outCalcRouteNodeA, outCalcRouteNodeB, inSourceFileName)
	Dim tNode, tXPathString, tTraderNode, tGTPNode, tSectionNode
	
	' 01 // Prepare
	fCalcRoutePrepare = False 'inXMLCalcRoute
	Set outCalcRouteNodeA = Nothing
	Set outCalcRouteNodeB = Nothing
	
	' 02 // Node A
	Set tTraderNode = inVersionNodeA.SelectSingleNode("ancestor::trader")
	Set tGTPNode = inVersionNodeA.SelectSingleNode("ancestor::gtp")
	Set tSectionNode = inVersionNodeA.SelectSingleNode("ancestor::section")
	tXPathString = "//trader[@id='" & tTraderNode.getAttribute("id") & "']/gtp[@id='" & tGTPNode.getAttribute("id") & "']/section[@id='" & tSectionNode.getAttribute("id") & "']/version[@id='" & inVersionNodeA.getAttribute("id") & "']"
	Set tNode = inXMLCalcRoute.SelectSingleNode(tXPathString)
	
	If tNode Is Nothing Then
		'CREATING
		Set tNode = fCalcRouteNodeCreate(inVersionNodeA, inXMLCalcRoute, inSourceFileName)
	Else
		'CLEARING
		While Not (tNode.FirstChild Is Nothing)
			tNode.RemoveChild(tNode.FirstChild)
		Wend
		tNode.SetAttribute "comment", "source file " & inSourceFileName
	End If
	
	Set outCalcRouteNodeA = tNode
	
	' 03 // Node B
	If Not inVersionNodeB Is Nothing Then
		Set tTraderNode = inVersionNodeB.SelectSingleNode("ancestor::trader")
		Set tGTPNode = inVersionNodeB.SelectSingleNode("ancestor::gtp")
		Set tSectionNode = inVersionNodeB.SelectSingleNode("ancestor::section")
		tXPathString = "//trader[@id='" & tTraderNode.getAttribute("id") & "']/gtp[@id='" & tGTPNode.getAttribute("id") & "']/section[@id='" & tSectionNode.getAttribute("id") & "']/version[@id='" & inVersionNodeA.getAttribute("id") & "']"
		Set tNode = inXMLCalcRoute.SelectSingleNode(tXPathString)
		
		If tNode Is Nothing Then
			'CREATING
			Set tNode = fCalcRouteNodeCreate(inVersionNodeB, inXMLCalcRoute, inSourceFileName)
		Else
			'CLEARING
			While Not (tNode.FirstChild Is Nothing)
				tNode.RemoveChild(tNode.FirstChild)
			Wend
			tNode.SetAttribute "comment", "source file " & inSourceFileName
		End If
		
		Set outCalcRouteNodeB = tNode
	End If
	
	' 04 // Over
	fCalcRoutePrepare = True
	Set tTraderNode = Nothing
	Set tGTPNode = Nothing
	Set tSectionNode = Nothing
	Set tNode = Nothing
End Function

Private Function fGetParentTraderNode(inNode, inTraderID)
	Dim tXPathString
	If inNode Is Nothing Then
		Set fGetParentTraderNode = Nothing
	Else
		tXPathString = "ancestor::trader[@id='" & inTraderID & "']"
		Set fGetParentTraderNode = inNode.SelectSingleNode(tXPathString)
	End If
End Function

Private Function fTPInjectCalcRoute(inCalcRouteNodeA, inCalcRouteNodeB, inXMLCalcRoute, inTPName, inTPMethod, inTPID, inTPTraderID, inTPDirection, inTPCoefficient, inTPMainFormula, inTPLossesFormula, outErrorText)
	Dim tFuncName, tNode, tXPathString, tCalcRouteNode, tRNode, tCNode
	
	' 01 \\ Prepare DATA
	fTPInjectCalcRoute = False
	outErrorText = vbNullString
	tFuncName = "fTPInject"
	Set tCalcRouteNode = Nothing
	
	' 02 \\ Lock calcnode by TRADER ID
	Set tNode = fGetParentTraderNode(inCalcRouteNodeA, inTPTraderID)
	If tNode Is Nothing Then
		Set tNode = fGetParentTraderNode(inCalcRouteNodeB, inTPTraderID)
		If tNode Is Nothing Then
			outErrorText = fGetWarnText(1, tFuncName, "Не удалось определить принадлежность точки по TraderID = <" & inTPTraderID & ">!" & vbCrLf & "STATUS > inCalcRouteNodeA = " & (Not inCalcRouteNodeA Is Nothing) & "; inCalcRouteNodeB = " & (Not inCalcRouteNodeB Is Nothing))
			Exit Function
		Else
			Set tCalcRouteNode = inCalcRouteNodeB
		End If
	Else
		Set tCalcRouteNode = inCalcRouteNodeA
	End If
	
	' 03 \\ Injecting node	
	' 03.01 \\ TPNode check & create
	Set tRNode = tCalcRouteNode
	Set tCNode = tRNode.SelectSingleNode("child::tp-aup[(@id-tp-aup='" & inTPID & "' and @tp-method='" & inTPMethod & "')]")
	If tCNode Is Nothing Then
		Set tCNode = tRNode.AppendChild(inXMLCalcRoute.CreateElement("tp-aup"))
		tCNode.SetAttribute "id-tp-aup", inTPID
		tCNode.SetAttribute "tp-method", inTPMethod
		tCNode.SetAttribute "tp-name", inTPName		
	End If
	
	' 03.02 \\ TPFormula check & create
	Set tRNode = tCNode
	Set tCNode = tRNode.SelectSingleNode("child::formula[@direction='" & inTPDirection & "']")
	If tCNode Is Nothing Then
		Set tCNode = tRNode.AppendChild(inXMLCalcRoute.CreateElement("formula"))
		tCNode.SetAttribute "direction", inTPDirection
		tCNode.SetAttribute "coefficient", inTPCoefficient
	Else
		outErrorText = fGetWarnText(1, tFuncName, "Формула для точки <" & inTPName & "> [" & inTPID & "/" & inTPMethod & "/" & inTPTraderID & "] уже присутствует в CalcRoute XML! Ошибка предварительной очистки или логики работы!")
		Exit Function
	End If
	
	' 03.03 \\ Formula injecting (MAIN and LOSSES)
	Set tRNode = tCNode
	
	' 03.03.01 \\ MAIN Formula
	Set tCNode = tRNode.AppendChild(inXMLCalcRoute.CreateElement("main"))
	tCNode.Text = inTPMainFormula
	
	' 03.03.01 \\ LOSSES Formula
	If inTPLossesFormula <> vbNullString Then
		Set tCNode = tRNode.AppendChild(inXMLCalcRoute.CreateElement("losses"))
		tCNode.Text = inTPLossesFormula
	End If
	
	' 04 \\ Over
	Set tCNode = Nothing
	Set tRNode = Nothing
	Set tCalcRouteNode = Nothing
	fTPInjectCalcRoute = True
End Function

Private Function fGetXML600XX(inFile, outXML, outClass, outVersion)
	Dim tNode, tValue
	
	' 01 \\ Prepare DATA
	fGetXML600XX = False
	outClass = vbNullString
	outVersion = 0
	Set outXML = Nothing
	
	' 02 \\ Preventive CHECK: #1 IsXML; #2 IsExists;
	If LCase(Right(inFile.Name, 4)) <> ".xml" Then: Exit Function
	If Not gFSO.FileExists(inFile.Path) Then: Exit Function
	
	' 03 \\ Reading XML file
	Set outXML = CreateObject("Msxml2.DOMDocument.6.0")
	outXML.ASync = False
	outXML.Load inFile.Path
	
	' 04 \\ Parse CHECK (no LOG)
	If outXML.parseError.ErrorCode <> 0 Then: Exit Function
	
	' So we got a VALID XML file, lets read headers
	' 05 \\ Root node name CHECK
	Set tNode = outXML.DocumentElement
	If tNode.NodeName <> "message" Then: Exit Function
	
	' 06 \\ Get CLASS
	tValue = tNode.getAttribute("class")
	If IsNull(tValue) Then: Exit Function
	outClass = tValue
	
	' 07 \\ Get VERSION
	tValue = tNode.getAttribute("version")
	If IsNull(tValue) Then: Exit Function
	outVersion = tValue
	
	' 08 \\ Complex filter
	If outClass = "60002" Then: fGetXML600XX = True
	
End Function

Private Function fGetCalcSide(inXML, inClass, inVersion, outIsComplex, inXMLBasis, outBasisNodeA, outBasisNodeB, outTextError)
	Dim tXPathString, tFuncName, tTextError, tTextList, tNodes, tNode, tValue
	Dim tCalcSide

	' 01 \\ Prepare DATA
	fGetCalcSide = False
	outTextError = vbNullString
	outIsComplex = False
	'outPSIReverse = False
	tFuncName = "fGetCalcSide"
	
	' 02 \\ Check for XML
	If inXML Is Nothing Then
		outTextError = fGetWarnText(1, tFuncName, "На входе пустой XML!")
		Exit Function
	End If
	
	' 03 \\ Reading	
	If inClass = "60002" Then 
		Select Case inVersion
			Case "1": 				
				
				'Определим CALC-SIDE
				tXPathString = "//body/psi"				
				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "calc-side", tCalcSide, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If
				
				' ОСОБЫЙ СЛУЧАЙ - Алгоритм для двух сторон
				If tCalcSide = "3" Then 
					
					'SIDE A
					tXPathString = "//body/dictionaries/organizations/organization[@id-org='1']"				
					If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "trader-code", tValue, tTextError) Then
						outTextError = fGetWarnText(1, tFuncName, tTextError)
						Exit Function
					End If
					
					Set outBasisNodeA = inXMLBasis.SelectSingleNode("//trader[@id='" & tValue & "']")
					
					If outBasisNodeA Is Nothing Then
						outTextError = fGetWarnText(1, tFuncName, "Импорт невозможен! BASIS не содержит торговца [" & tValue & "]!")
						Exit Function
					End If
					
					'SIDE B
					tXPathString = "//body/dictionaries/organizations/organization[@id-org='2']"				
					If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "trader-code", tValue, tTextError) Then
						outTextError = fGetWarnText(1, tFuncName, tTextError)
						Exit Function
					End If
					
					Set outBasisNodeB = inXMLBasis.SelectSingleNode("//trader[@id='" & tValue & "']")
					
					If outBasisNodeB Is Nothing Then
						outTextError = fGetWarnText(1, tFuncName, "Импорт невозможен! BASIS не содержит торговца [" & tValue & "]!")
						Exit Function
					End If
					
				Else
				
					'SIDE X to A
					tXPathString = "//body/dictionaries/organizations/organization[@id-org='" & tCalcSide & "']"				
					If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "trader-code", tValue, tTextError) Then
						outTextError = fGetWarnText(1, tFuncName, tTextError)
						Exit Function
					End If
					
					Set outBasisNodeA = inXMLBasis.SelectSingleNode("//trader[@id='" & tValue & "']")
					
					If outBasisNodeA Is Nothing Then
						outTextError = fGetWarnText(1, tFuncName, "Импорт невозможен! BASIS не содержит торговца [" & tValue & "]!")
						Exit Function
					End If
				End If
				
				outIsComplex = (tCalcSide = 3)
				fGetCalcSide = True
		End Select
	End If

End Function

Private Function fGetPeretok(inXML, inClass, inVersion, outPeretokNode, outGTPCodeFrom, outGTPCodeTo, outTraderCodeFrom, outTraderCodeTo, outTextError)
	Dim tXPathString, tNode, tValue, tFuncName, tTextError
	Dim tTempFrom, tTempTo, tTempOrgID

	' 01 \\ Prepare DATA
	fGetPeretok = False
	outTextError = vbNullString
	outGTPCodeFrom = vbNullString
	outGTPCodeTo = vbNullString
	outTraderCodeFrom = vbNullString
	outTraderCodeTo = vbNullString
	Set outPeretokNode = Nothing
	tFuncName = "fGetPeretok"
	
	' 02 \\ Check for XML
	If inXML Is Nothing Then
		outTextError = fGetWarnText(1, tFuncName, "На входе пустой XML!")
		Exit Function
	End If
	
	' 03 \\ Reading	
	If inClass = "60002" Then 
		Select Case inVersion
			Case "1":
				tXPathString = "//body/algorithm/peretok"
								
				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "id-gtp-from", tTempFrom, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If
				
				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "id-gtp-to", tTempTo, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If
				
				Set outPeretokNode = inXML.SelectSingleNode(tXPathString)
				
				'FROM
				tXPathString = "//body/dictionaries/gtps/gtpp[@id-gtp='" & tTempFrom & "']"				
							
				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "gtp-code", outGTPCodeFrom, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If

				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "id-org", tTempOrgID, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If

				tXPathString = "//body/dictionaries/organizations/organization[@id-org='" & tTempOrgID & "']"				
							
				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "trader-code", outTraderCodeFrom, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If
				
				'TO				
				tXPathString = "//body/dictionaries/gtps/gtpp[@id-gtp='" & tTempTo & "']"				
							
				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "gtp-code", outGTPCodeTo, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If

				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "id-org", tTempOrgID, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If

				tXPathString = "//body/dictionaries/organizations/organization[@id-org='" & tTempOrgID & "']"				
							
				If Not fGetAttribute(inXML, inClass, inVersion, tXPathString, "trader-code", outTraderCodeTo, tTextError) Then
					outTextError = fGetWarnText(1, tFuncName, tTextError)
					Exit Function
				End If
		End Select
	End If
	
	If (outGTPCodeFrom <> vbNullString) And (outGTPCodeTo <> vbNullString) And (Not outPeretokNode Is Nothing) Then: fGetPeretok = True
	
End Function

Private Function fGetAttribute(inXML, inClass, inVersion, inXPathString, inAttributeName, outValue, outTextError)
	Dim tFuncName, tNode, tValue
	
	' 01 // Prepare DATA
	fGetAttribute = False
	outValue = vbNullString
	outTextError = vbNullString
	tFuncName = "fGetAttribute"
	
	' 02 // Get NODE
	Set tNode = inXML.SelectSingleNode(inXPathString)
	If tNode Is Nothing Then
		outTextError = fGetWarnText(1, tFuncName, "Не удалось обнаружить ноду XPath = " & inXPathString & "! CLASS=" & inClass & "; VERSION=" & inVersion)
		Exit Function
	End If
	
	' 03 // Get Attribute
	tValue = tNode.getAttribute(inAttributeName)
	If IsNull(tValue) Then
		outTextError = fGetWarnText(1, tFuncName, "Не удалось обнаружить аттрибут @" & inAttributeName & " ноды XPath = " & inXPathString & "! CLASS=" & inClass & "; VERSION=" & inVersion)
		Exit Function
	End If
	
	' 04 // Over
	fGetAttribute = True
	outValue = tValue
	Set tNode = Nothing
End Function

Private Function fFileDataExtract(inFile, inXMLCalcRoute, inXMLBasis, outFilesCount, outInjectionsCount, outErrorText)
	Dim tNode, tValue, tTraderID, tTraderINN, tBTraderNode, tSectionNode, tGTPFrom, tGTPTo, tVersionNodeA, tVersionNodeB, tFormula, tPointsNode, tPointNode, tPointDirectionNode, tCRNode, tRewrite, tVersionID, tIndex, tFormulaNode
	Dim tTPName, tTPMethod, tTPID, tTPAIISCode, tTPTraderID, tTPDirection, tTPCoefficient, tTPFormula, tTPMainFormula, tTPLossesFormula, tCalcSide
	Dim tErrorText, tFuncName
	Dim tVersion, tClass, tXMLFile, tPSIReverse
	Dim tCalcRouteNodeA, tCalcRouteNodeB
	Dim tBasisSideANode, tBasisSideBNode, tTraderFrom, tTraderTo, tIsComplex

	' 01 \\ Avoid non-format [SOURCE]
	outInjectionsCount = 0 'STAT
	outErrorText = vbNullString
	tFuncName = "fFileDataExtract"
	fFileDataExtract = False
	tTraderID = vbNullString
	tTraderINN = vbNullString	
	
	' 02 \\ Open XML file and detect class [SOURCE]
	If Not fGetXML600XX(inFile, tXMLFile, tClass, tVersion) Then
		Set tXMLFile = Nothing
		Exit Function
	End If
	
	' 03 \\ Version CHECK [SOURCE]
	tValue = False
	If tClass = "60002" Then 
		Select Case tVersion
			Case "1": tValue = True			
		End Select
	End If
	
	If Not tValue Then
		outErrorText = fGetWarnText(1, tFuncName, "Version unsuppored! CLASS=" & tClass & "; VERSION=" & tVersion)
		Set tXMLFile = Nothing		
		Exit Function
	End If

	' 04 \\ Get algorithm owners [SOURCE][BASIS]
	If Not fGetCalcSide(tXMLFile, tClass, tVersion, tIsComplex, inXMLBasis, tBasisSideANode, tBasisSideBNode, tErrorText) Then
		outErrorText = fGetWarnText(1, tFuncName, tErrorText)
		Set tXMLFile = Nothing		
		Exit Function
	End If	
	
	' 06 \\ Lock PERETOK [SOURCE]
	If Not fGetPeretok(tXMLFile, tClass, tVersion, tSectionNode, tGTPFrom, tGTPTo, tTraderFrom, tTraderTo, tErrorText) Then
		outErrorText = fGetWarnText(1, tFuncName, tErrorText)
		Set tXMLFile = Nothing
		Exit Function
	End If

	' 07 \\ Lock section version to attach formula [BASIS]
	If Not fSelectSectionVersion(inXMLBasis, tIsComplex, tGTPFrom, tGTPTo, tTraderFrom, tTraderTo, tVersionNodeA, tVersionNodeB, tErrorText) Then
		outErrorText = fGetWarnText(1, tFuncName, tErrorText)
		Set tXMLFile = Nothing
		Exit Function
	End If	
	tVersionID = tVersionNodeA.getAttribute("id")
		
	' 08 \\ Extract point list [SOURCE] 
	' <peretok> node parsing - algorithm enries
	Set tPointsNode = tSectionNode.SelectNodes("child::calcformula-or-rr") ' <calcformula-or-rr> childs of PERETOK
	If tPointsNode.Length = 0 Then
		outErrorText = fGetWarnText(1, tFuncName, "Не обнаружено нод <child::calcformula-or-rr> в блоке <PERETOK> исходного файла-алгоритма!")
		Set tXMLFile = Nothing
		Exit Function
	End If	
	'WScript.Echo "From=" & tGTPFrom & "(" & tTraderFrom & ") -> To=" & tGTPTo & "(" & tTraderTo & ") :: V" & tVersionID & vbCrLf & "COMPLEX ALGO = " & tIsComplex & vbCrLf & "Algorithm POINTS = " & tPointsNode.Length
	
	' 09 \\ CalcRoute CFG prepare [CALCROUTE]
	' Will create empty nodes (or CLEAR data) for importing algorithm
	If Not fCalcRoutePrepare(tVersionNodeA, tVersionNodeB, inXMLCalcRoute, tCalcRouteNodeA, tCalcRouteNodeB, inFile.Name) Then		
		Set tXMLFile = Nothing
		Exit Function
	End If	

	'fSaveXMLConfigChanges gXMLCalcRoutePathLock, gXMLCalcRoute
	'Exit Function
	
	' 10 \\ Extract & inject formulas [SOURCE\CALCROUTE]
	For Each tPointNode In tPointsNode				
		'error check
		If tPointNode.ChildNodes.Length < 1 Then
			outErrorText = fGetWarnText(1, tFuncName, "Ошибка! Количество дочерних нод ноды <calcformula-or-rr> не может быть меньше 1!")
			Set tXMLFile = Nothing
			Exit Function
		End If
				
		'child node extraction
		For Each tPointDirectionNode In tPointNode.ChildNodes
			If fExtractPointDirectionNode(tPointDirectionNode, tClass, tVersion, tTPName, tTPMethod, tTPID, tTPAIISCode, tTPTraderID, tTPDirection, tTPCoefficient, tTPMainFormula, tTPLossesFormula, tErrorText) Then
				'WScript.Echo "TRADER=" & tTPTraderID & vbCrLf & vbCrLf & "METHOD=" & tTPMethod & vbCrLf & vbCrLf & "POINTName=" & tTPName & vbCrLf & vbCrLf & tTPMainFormula & vbCrLf & vbCrLf & tTPLossesFormula & vbCrLf & "COEF = " & tTPCoefficient				
				
				'for other side injection it must be reversed
				If tTPTraderID <> tTraderFrom Then: tTPCoefficient = tTPCoefficient * -1

				'inject data
				If Not fTPInjectCalcRoute(tCalcRouteNodeA, tCalcRouteNodeB, inXMLCalcRoute, tTPName, tTPMethod, tTPID, tTPTraderID, tTPDirection, tTPCoefficient, tTPMainFormula, tTPLossesFormula, tErrorText) Then
					outErrorText = fGetWarnText(1, tFuncName, tErrorText)
					Set tXMLFile = Nothing
					Exit Function
				End If
				outInjectionsCount = outInjectionsCount + 1 'STAT
			Else
				outErrorText = fGetWarnText(1, tFuncName, tErrorText)
				Set tXMLFile = Nothing
				Exit Function
			End If			
		Next
		' fSaveXMLConfigChanges gXMLCalcRoutePathLock, gXMLCalcRoute
		' Exit Function
	Next
	
	' 11 \\ Save changes
	fSaveXMLConfigChanges gXMLCalcRoutePathLock, gXMLCalcRoute
	outFilesCount = outFilesCount + 1 'STAT
	fFileDataExtract = True
	
	' 00 \\
	' 00 \\
End Function

Private Sub fInit()	
	Set gFSO = CreateObject("Scripting.FileSystemObject")
	gScriptFileName = Wscript.ScriptName
	gScriptPath = gFSO.GetParentFolderName(WScript.ScriptFullName)
	Set gWSO = CreateObject("WScript.Shell")
	gMainDelimiter = ";"
	gInsideDelimiter = ":"
	gErrorText = vbNullString
	gFilesCount = 0 
	gInjectionsCount = 0
	gTotalInjections = 0
End Sub

' MAIN Code block
Private Sub fMain()
	Dim tFile, tFilePath, tErrors

	' 01 \\ Set CFG directory
	gXMLFilePathA = gWSO.ExpandEnvironmentStrings("%HOMEPATH%") & "\GTPCFG"
	gXMLBasisPathLock = gXMLFilePathA
	gXMLCalcRoutePathLock = gXMLFilePathA
	tErrors = 0
	
	' 02 \\ Get BASIS XML Config [as GLOBAL value]
	If Not fGetXMLConfig(gXMLBasisPathLock, gXMLBasis, "Basis.xml", "BASIS") Then 
		WScript.Echo "Не удалось загрузить XML конфиг BASIS (или он не найден)!"
		fQuit
	End If
	
	' 03 \\ Get CALCROUTE XML Config [as GLOBAL value]
	If Not fGetXMLConfig(gXMLCalcRoutePathLock, gXMLCalcRoute, "CalcRoute.xml", "CALCROUTE") Then 
		gXMLCalcRoutePathLock = gXMLFilePathA
		If Not(fXMLCalcRouteConfigCreate(gXMLCalcRoute, gXMLCalcRoutePathLock)) Then 
			WScript.Echo "Не удалось загрузить XML конфиг CALCROUTE (или он не найден)!"
			fQuit
		End If
	End If
	
	' 04 \\ Data extractor	
	If WScript.Arguments.Length > 0 Then
		'by ARGUMENT
		For Each tFilePath in WScript.Arguments
			If gFSO.FileExists(tFilePath) Then
				Set tFile = gFSO.GetFile(tFilePath)
				If Not fFileDataExtract(tFile, gXMLCalcRoute, gXMLBasis, gFilesCount, gInjectionsCount, gErrorText) Then
					If gErrorText <> vbNullString Then
						WScript.Echo "Файл: " & tFile.Name & vbCrLf & vbCrLf & gErrorText
						tErrors = tErrors + 1
					End If
				End If
			End If
		Next
	Else
		'by DIRECTORY SCAN
		For Each tFile in gFSO.GetFolder(gScriptPath).Files
			If Not fFileDataExtract(tFile, gXMLCalcRoute, gXMLBasis, gFilesCount, gInjectionsCount, gErrorText) Then
				If gErrorText <> vbNullString Then
					WScript.Echo "Файл: " & tFile.Name & vbCrLf & vbCrLf & gErrorText
					tErrors = tErrors + 1
				End If
			End If
		Next
	End If
	
	If tErrors = 0 Then
		WScript.Echo "Успешно завершено!"
	Else
		WScript.Echo "Завершено с ошибками!"
	End If
End Sub

'======= // START
fInit
fMain
fQuit