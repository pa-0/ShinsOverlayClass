;Direct2d overlay class by Spawnova (5/27/2022)
;
;I'm not a professional programmer, I do this for fun, if it doesn't work for you I can try and help
;but I can't promise I will be able to solve the issue
;
;Special thanks to teadrinker for helping me understand some 64bit param structures! -> https://www.autohotkey.com/boards/viewtopic.php?f=76&t=105420

class ShinsOverlayClass {

	;x_orTitle		:		x pos of overlay OR title of window to attach to
	;y				:		y pos of overlay
	;w				:		width of overlay
	;h				:		height of overlay
	;guiID			:		name of the ahk gui id for the overlay window
	;
	;notes			:		if planning to attach to window these parameters can all be left blank
	
	__New(x_orTitle:=0,y:=0,width:=0,height:=0,guiID:="ShinsOverlayClass") {
	
	
		;[input variables] you can change these to affect the way the script behaves
		
		this.interpolationMode := 0 ;0 = nearestNeighbor, 1 = linear ;affects DrawImage() scaling 
	
	
	
		;[output variables] you can read these to get extra info, DO NOT MODIFY THESE
		
		this.x := x_orTitle			;overlay x position relative to screen
		this.y := y					;overlay y position relative to screen
		this.width := width			;overlay width
		this.height := height		;overlay height
		this.x2 := x_orTitle+width
		this.y2 := y+height
		this.attachHWND := 0			;HWND of the attached window, 0 if not attached
		this.attachClient := 0		;1 if using client space, 0 otherwise
		this.attachForeground := 0	;1 if overlay is only drawn when the attached window is the active window; 0 otherwise
		
		;Generally with windows there are invisible borders that allow
		;the window to be resized, but it makes the window larger
		;these values should contain the window x, y offset and width, height for actual postion and size
		this.realX := 0
		this.realY := 0
		this.realWidth := 0
		this.realHeight := 0
		this.realX2 := 0
		this.realY2 := 0
	
	
	
	
	
	
		;#############################
		;	Setup internal stuff
		;#############################
		this.bits := (a_ptrsize == 8)
		this.imageCache := []
		this.fonts := []
		this.lastPos := 0
		this.offX := 0
		this.offY := 0
		this.lastCol := 0
		
		this.LoadLib("d2d1","dwrite","dwmapi","gdiplus")
		VarSetCapacity(gsi, 24, 0)
		NumPut(1,gsi,0,"uint")
		DllCall("gdiplus\GdiplusStartup", "Ptr*", token, "Ptr", &gsi, "Ptr", 0)
		this.gdiplusToken := token
		this._guid("{06152247-6f50-465a-9245-118bfd3b6007}",clsidFactory)
		this._guid("{b859ee5a-d838-4b5b-a2e8-1adc7d93db48}",clsidwFactory)

		gui %guiID%: +hwndhwnd -Caption +E0x20 +E0x80000 +AlwaysOnTop +ToolWindow
		this.hwnd := hwnd
		DllCall("ShowWindow","ptr",this.hwnd,"uint",8)

		this.tBufferPtr := this.SetVarCapacity("ttBuffer",4096)
		this.rect1Ptr := this.SetVarCapacity("_rect1",64)
		this.rect2Ptr := this.SetVarCapacity("_rect2",64)
		this.rtPtr := this.SetVarCapacity("_rtPtr",64)
		this.hrtPtr := this.SetVarCapacity("_hrtPtr",64)
		this.matrixPtr := this.SetVarCapacity("_matrix",64)
		this.colPtr := this.SetVarCapacity("_colPtr",64)
		this.clrPtr := this.SetVarCapacity("_clrPtr",64)
		VarSetCapacity(margins,16)
		NumPut(-1,margins,0,"int"), NumPut(-1,margins,4,"int"), NumPut(-1,margins,8,"int"), NumPut(-1,margins,12,"int")
		if (DllCall("dwmapi\DwmExtendFrameIntoClientArea","Ptr",hwnd,"ptr",&margins) != 0) {
			this.Err("Problem with DwmExtendFrameIntoClientArea","overlay will not function")
			return
		}
		DllCall("SetLayeredWindowAttributes","Ptr",hwnd,"Uint",0,"char",255,"uint",2)
		if (DllCall("d2d1\D2D1CreateFactory","uint",1,"Ptr",&clsidFactory,"uint*",0,"Ptr*",factory) != 0) {
			this.Err("Problem creating factory","overlay will not function")
			return
		}
		this.factory := factory
		NumPut(1,this.tBufferPtr,16,"float")
		if (DllCall(this.vTable(this.factory,11),"ptr",this.factory,"ptr",this.tBufferPtr,"ptr",0,"uint",0,"ptr*",stroke) != 0) {
			this.Err("Problem creating stroke","overlay will not function")
			return
		}
		this.stroke := stroke
		NumPut(2,this.tBufferPtr,0,"uint")
		NumPut(2,this.tBufferPtr,4,"uint")
		NumPut(2,this.tBufferPtr,12,"uint")
		NumPut(1,this.tBufferPtr,16,"float")
		if (DllCall(this.vTable(this.factory,11),"ptr",this.factory,"ptr",this.tBufferPtr,"ptr",0,"uint",0,"ptr*",stroke) != 0) {
			this.Err("Problem creating rounded stroke","overlay will not function")
			return
		}
		this.strokeRounded := stroke
		NumPut(1,this.rtPtr,8,"uint")
		NumPut(96,this.rtPtr,12,"float")
		NumPut(96,this.rtPtr,16,"float")
		NumPut(hwnd,this.hrtPtr,0,"Ptr")
		NumPut(width,this.hrtPtr,a_ptrsize,"uint")
		NumPut(height,this.hrtPtr,a_ptrsize+4,"uint")
		NumPut(2,this.hrtPtr,a_ptrsize+8,"uint")
		if (DllCall(this.vTable(this.factory,14),"Ptr",this.factory,"Ptr",this.rtPtr,"ptr",this.hrtPtr,"Ptr*",renderTarget) != 0) {
			this.Err("Problem creating renderTarget","overlay will not function")
			return
		}
		this.renderTarget := renderTarget
		NumPut(1,this.matrixPtr,0,"float")
		this.SetIdentity(4)
		if (DllCall(this.vTable(this.renderTarget,8),"Ptr",this.renderTarget,"Ptr",this.colPtr,"Ptr",this.matrixPtr,"Ptr*",brush) != 0) {
			this.Err("Problem creating brush","overlay will not function")
			return
		}
		this.brush := brush
		DllCall(this.vTable(this.renderTarget,32),"Ptr",this.renderTarget,"Uint",1)
		if (DllCall("dwrite\DWriteCreateFactory","uint",0,"Ptr",&clsidwFactory,"Ptr*",wFactory) != 0) {
			this.Err("Problem creating writeFactory","overlay will not function")
			return
		}
		this.wFactory := wFactory
		
		if (winexist(x_orTitle))
			this.AttachToWindow(x_orTitle)
		 else
			this.SetPosition(x_orTitle,y)
		
		this.BeginDraw()
		this.EndDraw()
	}
	
	
	;####################################################################################################################################################################################################################################
	;AttachToWindow
	;
	;title				:				Title of the window (or other type of identifier such as 'ahk_exe notepad.exe' etc..
	;attachToClientArea	:				Whether or not to attach the overlay to the client area, window area is used otherwise
	;foreground			:				Whether or not to only draw the overlay if attached window is active in the foreground, otherwise always draws
	;
	;return				;				Returns 1 if either attached window is active in the foreground or no window is attached; 0 otherwise
	;
	;Notes				;				Does not actually 'attach', but rather every BeginDraw() fuction will check to ensure it's 
	;									updated to the attached windows position/size
	;									Could use SetParent but it introduces other issues, I'll explore further later
	
	AttachToWindow(title,AttachToClientArea:=0,foreground:=1) {
		if (title = "") {
			this.Err("AttachToWindow: Error","Expected title string, but empty variable was supplied!")
			return 0
		}
		if (!this.attachHWND := winexist(title)) {
			this.Err("AttachToWindow: Error","Could not find window - " title)
			return 0
		}
		if (AttachToClientArea) {
			if (!DllCall("GetWindowRect","ptr",this.attachHWND,"ptr",this.tBufferPtr)) {
				this.Err("AttachToWindow: Error","Problem getting client rect, is window minimized?")
				return 0
			}
			this.AdjustClient(x,y,w,h)
		} else {
			if (!DllCall("GetWindowRect","ptr",this.attachHWND,"ptr",this.tBufferPtr)) {
				this.Err("AttachToWindow: Error","Problem getting window rect, is window minimized?")
				return 0
			}
			this.AdjustWindow(x,y,w,h)
		}
		this.attachClient := AttachToClientArea
		this.attachForeground := foreground
		VarSetCapacity(newSize,16)
		NumPut(this.width,newSize,0,"uint")
		NumPut(this.height,newSize,4,"uint")
		DllCall(this.vTable(this.renderTarget,58),"Ptr",this.renderTarget,"ptr",&newsize)
		this.SetPosition(x,y,this.width,this.height)
	}
	
	
	;####################################################################################################################################################################################################################################
	;BeginDraw
	;
	;return				;				Returns 1 if either attached window is active in the foreground or no window is attached; 0 otherwise
	;
	;Notes				;				Must always call EndDraw to finish drawing and update the overlay
	
	BeginDraw() {
		if (this.attachHWND) {
			if (!DllCall("GetWindowRect","ptr",this.attachHWND,"ptr",this.tBufferPtr) or (this.attachForeground and DllCall("GetForegroundWindow") != this.attachHWND)) {
				DllCall(this.vTable(this.renderTarget,48),"Ptr",this.renderTarget)
				DllCall(this.vTable(this.renderTarget,47),"Ptr",this.renderTarget,"Ptr",this.clrPtr)
				this.EndDraw()
				return 0
			}
			x := NumGet(this.tBufferPtr,0,"int")
			y := NumGet(this.tBufferPtr,4,"int")
			w := NumGet(this.tBufferPtr,8,"int")-x
			h := NumGet(this.tBufferPtr,12,"int")-y
			if ((w<<16)+h != this.lastSize) {
				this.AdjustWindow(x,y,w,h)
				VarSetCapacity(newSize,16)
				NumPut(this.width,newSize,0,"uint")
				NumPut(this.height,newSize,4,"uint")
				DllCall(this.vTable(this.renderTarget,58),"Ptr",this.renderTarget,"ptr",&newsize)
				this.SetPosition(x,y)
			} else if ((x<<16)+y != this.lastPos) {
				this.AdjustWindow(x,y,w,h)
				this.SetPosition(x,y)
			}
		}
		DllCall(this.vTable(this.renderTarget,48),"Ptr",this.renderTarget)
		DllCall(this.vTable(this.renderTarget,47),"Ptr",this.renderTarget,"Ptr",this.clrPtr)
		return 1
	}
	
	
	;####################################################################################################################################################################################################################################
	;EndDraw
	;
	;return				;				Void
	;
	;Notes				;				Must always call EndDraw to finish drawing and update the overlay
	
	EndDraw() {
		DllCall(this.vTable(this.renderTarget,49),"Ptr",this.renderTarget,"int64*",tag1,"int64*",tag2)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawImage
	;
	;dstX				:				X position to draw to
	;dstY				:				Y position to draw to
	;dstW				:				Width of image to draw to
	;dstH				:				Height of image to draw to
	;srcX				:				X position to draw from
	;srcY				:				Y position to draw from
	;srcW				:				Width of image to draw from
	;srcH				:				Height of image to draw from
	;drawCentered		:				Draw the image centered on dstX/dstY, otherwise dstX/dstY will be the top left of the image
	;rotation			:				Image rotation in degrees (0-360)
	;
	;return				;				Void
	
	DrawImage(image,dstX,dstY,dstW:=0,dstH:=0,srcX:=0,srcY:=0,srcW:=0,srcH:=0,drawCentered:=0,rotation:=0) {
		if (!i := this.imageCache[image]) {
			i := this.cacheImage(image)
		}
		x := dstX-(drawCentered?i.w/2:0)
		y := dstY-(drawCentered?i.h/2:0)
		NumPut(x,this.rect1Ptr,0,"float")
		NumPut(y,this.rect1Ptr,4,"float")
		NumPut(x + (dstW=0?i.w:dstW),this.rect1Ptr,8,"float")
		NumPut(y + (dstH=0?i.h:dstH),this.rect1Ptr,12,"float")
		NumPut(srcX,this.rect2Ptr,0,"float")
		NumPut(srcY,this.rect2Ptr,4,"float")
		NumPut(srcX + (srcW=0?i.w:srcW),this.rect2Ptr,8,"float")
		NumPut(srcY + (srcH=0?i.h:srcH),this.rect2Ptr,12,"float")
		
		if (rotation != 0) {
			if (this.bits) {
				NumPut(dstX+(dstW/2),this.tBufferPtr,0,"float")
				NumPut(dstY+(dstH/2),this.tBufferPtr,4,"float")
				DllCall("d2d1\D2D1MakeRotateMatrix","float",rotation,"double",NumGet(this.tBufferPtr,"double"),"ptr",this.matrixPtr)
			} else {
				DllCall("d2d1\D2D1MakeRotateMatrix","float",rotation,"float",dstX+(dstW/2),"float",dstY+(dstH/2),"ptr",this.matrixPtr)
			}
			DllCall(this.vTable(this.renderTarget,30),"ptr",this.renderTarget,"ptr",this.matrixPtr)
			DllCall(this.vTable(this.renderTarget,26),"ptr",this.renderTarget,"ptr",i.p,"ptr",this.rect1Ptr,"float",1,"uint",this.interpolationMode,"ptr",this.rect2Ptr)
			this.SetIdentity()
			DllCall(this.vTable(this.renderTarget,30),"ptr",this.renderTarget,"ptr",this.matrixPtr)
		} else {
			DllCall(this.vTable(this.renderTarget,26),"ptr",this.renderTarget,"ptr",i.p,"ptr",this.rect1Ptr,"float",1,"uint",this.interpolationMode,"ptr",this.rect2Ptr)
		}
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawText
	;
	;text				:				The text to be drawn
	;x					:				X position
	;y					:				Y position
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;size				:				Font size
	;fontName			:				Font name (must be installed)
	;dropShadowColor	:				If a valid color a drop shadow will be added to the text
	;dropX				:				X offset for drop shadow
	;dropY				:				Y offset for drop shadow
	;
	;return				;				Void
	
	DrawText(text,x,y,color:=0xFFFFFFFF,size:=18,fontName:="Arial",dropShadowColor:=-1,dropx:=2,dropy:=2) {
		if (!p := this.fonts[fontName size]) {
			p := this.CacheFont(fontName,size)
		}
		if (dropShadowColor != -1) {
			this.DrawText(text,x+dropx,y+dropy,dropShadowColor,size,fontName)
		}
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(x+this.width,this.tBufferPtr,8,"float")
		NumPut(y+this.height,this.tBufferPtr,12,"float")
		DllCall(this.vTable(this.renderTarget,27),"ptr",this.renderTarget,"wstr",text,"uint",strlen(text),"ptr",p,"ptr",this.tBufferPtr,"ptr",this.brush,"uint",0,"uint",0)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawEllipse
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of ellipse
	;h					:				Height of ellipse
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void
	
	DrawEllipse(x, y, w, h, color, thickness:=1) {
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(w,this.tBufferPtr,8,"float")
		NumPut(h,this.tBufferPtr,12,"float")
		DllCall(this.vTable(this.renderTarget,20),"Ptr",this.renderTarget,"Ptr",this.tBufferPtr,"ptr",this.brush,"float",thickness,"ptr",this.stroke)
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillEllipse
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of ellipse
	;h					:				Height of ellipse
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;
	;return				;				Void
	
	FillEllipse(x, y, w, h, color) {
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(w,this.tBufferPtr,8,"float")
		NumPut(h,this.tBufferPtr,12,"float")
		DllCall(this.vTable(this.renderTarget,21),"Ptr",this.renderTarget,"Ptr",this.tBufferPtr,"ptr",this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawCircle
	;
	;x					:				X position
	;y					:				Y position
	;radius				:				Radius of circle
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void
	
	DrawCircle(x, y, radius, color, thickness:=1) {
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(radius,this.tBufferPtr,8,"float")
		NumPut(radius,this.tBufferPtr,12,"float")
		DllCall(this.vTable(this.renderTarget,20),"Ptr",this.renderTarget,"Ptr",this.tBufferPtr,"ptr",this.brush,"float",thickness,"ptr",this.stroke)
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillCircle
	;
	;x					:				X position
	;y					:				Y position
	;radius				:				Radius of circle
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;
	;return				;				Void
	
	FillCircle(x, y, radius, color) {
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(radius,this.tBufferPtr,8,"float")
		NumPut(radius,this.tBufferPtr,12,"float")
		DllCall(this.vTable(this.renderTarget,21),"Ptr",this.renderTarget,"Ptr",this.tBufferPtr,"ptr",this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawRectangle
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of rectangle
	;h					:				Height of rectangle
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void
	
	DrawRectangle(x, y, w, h, color, thickness:=1) {
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(x+w,this.tBufferPtr,8,"float")
		NumPut(y+h,this.tBufferPtr,12,"float")
		DllCall(this.vTable(this.renderTarget,16),"Ptr",this.renderTarget,"Ptr",this.tBufferPtr,"ptr",this.brush,"float",thickness,"ptr",this.stroke)
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillRectangle
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of rectangle
	;h					:				Height of rectangle
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;
	;return				;				Void
	
	FillRectangle(x, y, w, h, color) {
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(x+w,this.tBufferPtr,8,"float")
		NumPut(y+h,this.tBufferPtr,12,"float")
		DllCall(this.vTable(this.renderTarget,17),"Ptr",this.renderTarget,"Ptr",this.tBufferPtr,"ptr",this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawRoundedRectangle
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of rectangle
	;h					:				Height of rectangle
	;radiusX			:				The x-radius for the quarter ellipse that is drawn to replace every corner of the rectangle.
	;radiusY			:				The y-radius for the quarter ellipse that is drawn to replace every corner of the rectangle.
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void
	
	DrawRoundedRectangle(x, y, w, h, radiusX, radiusY, color, thickness:=1) {
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(x+w,this.tBufferPtr,8,"float")
		NumPut(y+h,this.tBufferPtr,12,"float")
		NumPut(radiusX,this.tBufferPtr,16,"float")
		NumPut(radiusY,this.tBufferPtr,20,"float")
		DllCall(this.vTable(this.renderTarget,18),"Ptr",this.renderTarget,"Ptr",this.tBufferPtr,"ptr",this.brush,"float",thickness,"ptr",this.stroke)
	}
	
	
	;####################################################################################################################################################################################################################################
	;FillRectangle
	;
	;x					:				X position
	;y					:				Y position
	;w					:				Width of rectangle
	;h					:				Height of rectangle
	;radiusX			:				The x-radius for the quarter ellipse that is drawn to replace every corner of the rectangle.
	;radiusY			:				The y-radius for the quarter ellipse that is drawn to replace every corner of the rectangle.
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;
	;return				;				Void
	
	FillRoundedRectangle(x, y, w, h, radiusX, radiusY, color) {
		this.SetBrushColor(color)
		NumPut(x,this.tBufferPtr,0,"float")
		NumPut(y,this.tBufferPtr,4,"float")
		NumPut(x+w,this.tBufferPtr,8,"float")
		NumPut(y+h,this.tBufferPtr,12,"float")
		NumPut(radiusX,this.tBufferPtr,16,"float")
		NumPut(radiusY,this.tBufferPtr,20,"float")
		DllCall(this.vTable(this.renderTarget,19),"Ptr",this.renderTarget,"Ptr",this.tBufferPtr,"ptr",this.brush)
	}
	
	
	;####################################################################################################################################################################################################################################
	;DrawLine
	;
	;x1					:				X position for line start
	;y1					:				Y position for line start
	;x2					:				X position for line end
	;y2					:				Y position for line end
	;color				:				Color in 0xAARRGGBB or 0xRRGGBB format (if 0xRRGGBB then alpha is set to FF (255))
	;thickness			:				Thickness of the line
	;
	;return				;				Void

	DrawLine(x1,y1,x2,y2,color,thickness:=1,rounded:=0) {
		this.SetBrushColor(color)
		if (this.bits) {
			NumPut(x1,this.tBufferPtr,0,"float")  ;Special thanks to teadrinker for helping me
			NumPut(y1,this.tBufferPtr,4,"float")  ;with these params!
			NumPut(x2,this.tBufferPtr,8,"float")
			NumPut(y2,this.tBufferPtr,12,"float")
			DllCall(this.vTable(this.renderTarget,15),"Ptr",this.renderTarget,"Double",NumGet(this.tBufferPtr,0,"double"),"Double",NumGet(this.tBufferPtr,8,"double"),"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke))
		} else {
			DllCall(this.vTable(this.renderTarget,15),"Ptr",this.renderTarget,"float",x1,"float",y1,"float",x2,"float",y2,"ptr",this.brush,"float",thickness,"ptr",(rounded?this.strokeRounded:this.stroke))
		}
		
	}
	
	;####################################################################################################################################################################################################################################
	;SetPosition
	;
	;x					:				X position to move the window to (screen space)
	;y					:				Y position to move the window to (screen space)
	;
	;return				;				Void
	;
	;notes				:				Only used when not attached to a window
	
	SetPosition(x,y,w:=0,h:=0) {
		this.x := x
		this.y := y
		DllCall("MoveWindow","Ptr",this.hwnd,"int",x,"int",y,"int",this.width,"int",this.height,"char",1)
	}
	
	
	;####################################################################################################################################################################################################################################
	;GetImageDimensions
	;
	;image				:				Image file name
	;&w					:				Width of image
	;&h					:				Height of image
	;
	;return				;				Void
	
	GetImageDimensions(image,byref w, byref h) {
		if (!i := this.imageCache[image]) {
			i := this.cacheImage(image)
		}
		w := i.w
		h := i.h
	}
	
	
	;####################################################################################################################################################################################################################################
	;GetMousePos
	;
	;&x					:				X position of mouse to return
	;&y					:				Y position of mouse to return
	;
	;return				;				Returns 1 if mouse within window/client region; 0 otherwise
	
	GetMousePos(byref x, byref y, realRegionOnly:=0) {
		DllCall("GetCursorPos","ptr",this.tBufferPtr)
		x := NumGet(this.tBufferPtr,0,"int")
		y := NumGet(this.tBufferPtr,4,"int")
		if (!realRegionOnly) {
			inside := (x >= this.x and y >= this.y and x <= this.x2 and y <= this.y2)
			x += this.offX
			y += this.offY
			return inside
		}
		x += this.offX
		y += this.offY
		return (x >= this.realX and y >= this.realY and x <= this.realX2 and y <= this.realY2)
		
	}
	

	
	
	
	
	
	
	
	
	
	
	
	
	;########################################## 
	;  internal functions used by the class
	;########################################## 
	AdjustWindow(byref x,byref y,byref w,byref h) {
		DllCall("GetWindowInfo","ptr",this.attachHWND,"ptr",this.tBufferPtr)
		pp := (this.attachClient ? 20 : 4)
		x1 := NumGet(this.tBufferPtr,pp,"int")
		y1 := NumGet(this.tBufferPtr,pp+4,"int")
		x2 := NumGet(this.tBufferPtr,pp+8,"int")
		y2 := NumGet(this.tBufferPtr,pp+12,"int")
		this.width := w := x2-x1
		this.height := h := y2-y1
		this.x := x := x1
		this.y := y := y1
		this.x2 := x + w
		this.y2 := y + h
		this.lastPos := (x1<<16)+y1
		this.lastSize := (w<<16)+h
		hBorders := (this.attachClient ? 0 : NumGet(this.tBufferPtr,48,"int"))
		vBorders := (this.attachClient ? 0 : NumGet(this.tBufferPtr,52,"int"))
		this.realX := hBorders
		this.realY := 0
		this.realWidth := w - (hBorders*2)
		this.realHeight := h - vBorders
		this.realX2 := this.realX + this.realWidth
		this.realY2 := this.realY + this.realHeight
		this.offX := -x1 ;- hBorders
		this.offY := -y1
	}
	SetIdentity(o:=0) {
		NumPut(1,this.matrixPtr,o+0,"float")
		NumPut(0,this.matrixPtr,o+4,"float")
		NumPut(0,this.matrixPtr,o+8,"float")
		NumPut(1,this.matrixPtr,o+12,"float")
		NumPut(0,this.matrixPtr,o+16,"float")
		NumPut(0,this.matrixPtr,o+20,"float")
	}
	Err(str*) {
		s := ""
		for k,v in str
			s .= (s = "" ? "" : "`n`n") v
		msgbox,% 0x30 | 0x1000,% "Problem!",% s
	}
	LoadLib(lib*) {
		for k,v in lib
			if (!DllCall("GetModuleHandle", "str", v, "Ptr"))
				DllCall("LoadLibrary", "Str", v) 
	}
	SetBrushColor(col) {
		if (col <= 0xFFFFFF)
			col += 0xFF000000
		if (col != this.lastCol) {
			NumPut(((col & 0xFF0000)>>16)/255,this.colPtr,0,"float")
			NumPut(((col & 0xFF00)>>8)/255,this.colPtr,4,"float")
			NumPut(((col & 0xFF))/255,this.colPtr,8,"float")
			NumPut((col > 0xFFFFFF ? ((col & 0xFF000000)>>24)/255 : 1),this.colPtr,12,"float")
			DllCall(this.vTable(this.brush,8),"Ptr",this.brush,"Ptr",this.colPtr)
			this.lastCol := col
			return 1
		}
		return 0
	}
	vTable(a,p) {
		return NumGet(NumGet(a+0,0,"ptr"),p*a_ptrsize,"Ptr")
	}
	_guid(guidStr,byref clsid) {
		VarSetCapacity(clsid,16)
		DllCall("ole32\CLSIDFromString", "WStr", guidStr, "Ptr", &clsid)
	}
	SetVarCapacity(key,size,fill=0) {
		this.SetCapacity(key,size)
		DllCall("RtlFillMemory","Ptr",this.GetAddress(key),"Ptr",size,"uchar",fill)
		return this.GetAddress(key)
	}
	CacheImage(image) {
		if (this.imageCache.haskey(image))
			return 1
		if (image = "") {
			this.Err("Error, expected resource image path but empty variable was supplied!")
			return 0
		}
		if (!FileExist(image)) {
			this.Err("Error finding resource image","'" image "' does not exist!")
			return 0
		}
		DllCall("gdiplus\GdipCreateBitmapFromFile", "Ptr", &image, "Ptr*", bm)
		DllCall("gdiplus\GdipGetImageWidth", "Ptr", bm, "Uint*", w)
		DllCall("gdiplus\GdipGetImageHeight", "Ptr", bm, "Uint*", h)
		VarSetCapacity(r,16,0)
		NumPut(w,r,8,"uint")
		NumPut(h,r,12,"uint")
		VarSetCapacity(bmdata, 32, 0)
		DllCall("Gdiplus\GdipBitmapLockBits", "Ptr", bm, "Ptr", &r, "uint", 3, "int", 0x26200A, "Ptr", &bmdata)
		scan := NumGet(bmdata, 16, "Ptr")
		p := DllCall("GlobalAlloc", "uint", 0x40, "ptr", 16+((w*h)*4), "ptr")
		loop % ((w*h)) {
			pp := (a_index-1)*4
			col := NumGet(scan+0,pp,"uint")
			a := (col&0xFF000000)>>24
			NumPut((col&0xFF0000)>>16*a/255,p+0,pp+0,"uchar")
			NumPut((col&0xFF00)>>8*a/255,p+0,pp+1,"uchar")
			NumPut((col&0xFF)*a/255,p+0,pp+2,"uchar")
			NumPut(a,p+0,pp+3,"uchar")
		}	
		DllCall("Gdiplus\GdipBitmapUnlockBits", "Ptr", bm, "Ptr", &bmdata)
		DllCall("gdiplus\GdipDisposeImage", "ptr", bm)
		VarSetCapacity(props,64,0)
		NumPut(28,props,0,"uint")
		NumPut(1,props,4,"uint")
		if (this.bits) {
			NumPut(w,this.tBufferPtr,0,"uint")
			NumPut(h,this.tBufferPtr,4,"uint")
			if (v := DllCall(this.vTable(this.renderTarget,4),"ptr",this.renderTarget,"int64",NumGet(this.tBufferPtr,"int64"),"ptr",p,"uint",4 * w,"ptr",&props,"ptr*",bitmap) != 0) {
				this.Err("Problem creating D2D bitmap for image '" image "'")
				return 0
			}
		} else {
			if (v := DllCall(this.vTable(this.renderTarget,4),"ptr",this.renderTarget,"uint",w,"uint",h,"ptr",p,"uint",4 * w,"ptr",&props,"ptr*",bitmap) != 0) {
				this.Err("Problem creating D2D bitmap for image '" image "'")
				return 0
			}
		}
		return this.imageCache[image] := {p:bitmap,w:w,h:h}
	}
	CacheFont(name,size) {
		if (DllCall(this.vTable(this.wFactory,15),"ptr",this.wFactory,"wstr",name,"ptr",0,"uint",400,"uint",0,"uint",5,"float",size,"wstr","en-us","ptr*",textFormat) != 0) {
			this.Err("Unable to create font: " name " (size: " size ")","Try a different font or check to see if " name " is a valid font!")
			return 0
		}
		return this.fonts[name size] := textFormat
	}
	_Delete() {
		DllCall("gdiplus\GdiplusShutdown", "Ptr*", this.gdiplusToken)
	}
	Mcode(str) {
		s := strsplit(str,"|")
		if (s.length() != 2)
			return
		if (!DllCall("crypt32\CryptStringToBinary", "str", s[this.bits+1], "uint", 0, "uint", 1, "ptr", 0, "uint*", pp, "ptr", 0, "ptr", 0))
			return
		p := DllCall("GlobalAlloc", "uint", 0, "ptr", pp, "ptr")
		if (this.bits)
			DllCall("VirtualProtect", "ptr", p, "ptr", pp, "uint", 0x40, "uint*", op)
		if (DllCall("crypt32\CryptStringToBinary", "str", s[this.bits+1], "uint", 0, "uint", 1, "ptr", p, "uint*", pp, "ptr", 0, "ptr", 0))
			return p
		DllCall("GlobalFree", "ptr", p)
	}
}
