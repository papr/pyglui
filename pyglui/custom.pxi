
cdef class Seek_Bar(UI_element):
    '''Seek bar that visualizes seek handles, trim marks and playback buttons

    Hover modes:
        0   Seek bar is not being hovered
        1   Seek handle is being hovered
        2   Right trim mark handle is being hovered
        3   Left trim mark handle is being hovered
        4   Seek bar is being hovered
    '''

    cdef int total
    cdef Vec2 point_click_seek_loc
    cdef readonly int hovering
    cdef FitBox bar, seek_handle, trim_left_handle, trim_right_handle
    cdef readonly bint seeking, trimming_left, trimming_right
    cdef Synced_Value trim_left, trim_right, current, playback_speed
    cdef object seeking_cb
    cdef Timeline_Menu handle_start_reference
    cdef Icon backwards, play, forwards

    def __cinit__(self, object ctx, int total, object seeking_cb,
                  Timeline_Menu handle_start_reference, *args, **kwargs):
        self.uid = id(self)
        self.trim_left = Synced_Value('trim_left', ctx, trigger_overlay_only=True)
        self.trim_right = Synced_Value('trim_right', ctx, trigger_overlay_only=True)
        self.current = Synced_Value('current_index', ctx, trigger_overlay_only=True)
        self.playback_speed = Synced_Value('playback_speed', ctx, trigger_overlay_only=True)
        self.seeking_cb = seeking_cb
        self.total = total
        self.hovering = 0
        self.seeking = False
        self.trimming_left = False
        self.trimming_right = False
        self.handle_start_reference = handle_start_reference

        self.point_click_seek_loc = Vec2(0., 0.)
        self.outline = FitBox(Vec2(0., -50.), Vec2(0., 0.))
        self.bar = FitBox(Vec2(130., 18.), Vec2(-30., 3.))
        self.seek_handle = FitBox(Vec2(0., 0.), Vec2(0., 0.))
        self.trim_left_handle = FitBox(Vec2(0., 0.), Vec2(0., 0.))
        self.trim_right_handle = FitBox(Vec2(0., 0.), Vec2(0., 0.))

        play_icon = chr(0xE037)
        pause_icon = chr(0xe034)
        step_fwd_icon = chr(0xe044)
        step_bwd_icon = chr(0xe045)
        incr_pbs_icon = chr(0xE01F)  # pbs: playback speed
        decr_pbs_icon = chr(0xE020)

        def set_play(_):
            if ctx.play:
                self.backwards.label = step_bwd_icon
                self.forwards.label = step_fwd_icon
                self.play.label = play_icon
                ctx.play = False
            else:
                self.backwards.label = decr_pbs_icon
                self.forwards.label = incr_pbs_icon
                self.play.label = pause_icon
                ctx.play = True

        self.backwards = Icon('backwards', ctx, label_font='pupil_icons',
                              label=step_bwd_icon,
                              getter=lambda: True,
                              hotkey=263)  # 263 = glfw.GLFW_KEY_LEFT
        self.forwards = Icon('forwards', ctx, label_font='pupil_icons',
                             label=step_fwd_icon,
                             hotkey=262,  # 262 = glfw.GLFW_KEY_RIGHT
                             getter=lambda: True)

        self.play = Icon('play', ctx, label_font='pupil_icons',
                         label=play_icon,
                         hotkey=32, # 32 = glfw.GLFW_KEY_SPACE
                         setter=set_play,
                         getter=lambda: True)

        self.backwards.outline = FitBox(Vec2(5, 0),Vec2(40, 40))
        self.play.outline = FitBox(Vec2(40, 0),Vec2(40, 40))
        self.forwards.outline = FitBox(Vec2(75, 0),Vec2(40, 40))

    def __init__(self, *args, **kwargs):
        pass

    cpdef sync(self):
        self.trim_left.sync()
        self.trim_right.sync()
        self.current.sync()
        self.playback_speed.sync()
        self.backwards.sync()
        self.play.sync()
        self.forwards.sync()

    cpdef draw(self,FitBox parent,bint nested=True, bint parent_read_only = False):
        self.outline.compute(parent)
        self.outline.sketch(RGBA(0., 0., 0., 0.3))
        self.bar.compute(self.outline)
        self.bar.sketch(RGBA(1., 1., 1., 0.4))

    cpdef draw_overlay(self,FitBox parent,bint nested=True, bint parent_read_only = False):

        self.backwards.draw(self.outline, nested=True, parent_read_only=False)
        self.play.draw(self.outline, nested=True, parent_read_only=False)
        self.forwards.draw(self.outline, nested=True, parent_read_only=False)

        cdef FitBox handle = FitBox(Vec2(0., 0.), Vec2(0., 0.))
        cdef int current_val = self.current.value
        cdef int trim_left_val = self.trim_left.value
        cdef int trim_right_val = self.trim_right.value
        cdef float seek_x = clampmap(current_val, 0, self.total, 0, self.bar.size.x)
        cdef float top_ext = self.handle_start_reference.element_space.org.y
        cdef float bot_ext = self.bar.org.y + self.bar.size.y + 20 * ui_scale
        cdef float selection_height = 5 * self.bar.size.y

        cdef float trim_l_x = clampmap(trim_left_val, 0, self.total, 0, self.bar.size.x)
        handle.org.x = int(self.bar.org.x + trim_l_x - selection_height)
        handle.org.y = self.bar.org.y + self.bar.size.y / 2 - selection_height / 2
        handle.size.x = selection_height
        handle.size.y = selection_height
        self.trim_left_handle = draw_trim_handle(handle, 0.25, RGBA(*seekbar_trim_color_hover if self.hovering == 3 else seekbar_trim_color))

        cdef float trim_r_x = clampmap(trim_right_val, 0, self.total, 0, self.bar.size.x)
        handle.org.x = int(self.bar.org.x + trim_r_x)
        handle.org.y = self.bar.org.y + self.bar.size.y / 2 - selection_height / 2
        self.trim_right_handle = draw_trim_handle(handle, 0.75, RGBA(*seekbar_trim_color_hover if self.hovering == 2 else seekbar_trim_color))

        # draw region between trim marks
        handle.size.x = handle.org.x - int(self.bar.org.x + trim_l_x)
        handle.org.x = int(self.bar.org.x + trim_l_x)
        handle.size.y = self.bar.size.y
        rect(handle.org, handle.size, RGBA(*seekbar_trim_color))

        handle.org.y += selection_height - handle.size.y
        rect(handle.org, handle.size, RGBA(*seekbar_trim_color))

        handle.org = Vec2(int(self.bar.org.x + seek_x - self.bar.size.y / 4), top_ext)
        handle.size = Vec2(self.bar.size.y / 2, bot_ext - top_ext)
        self.seek_handle = draw_seek_handle(handle, RGBA(*seekbar_seek_color_hover if self.hovering == 1 else seekbar_seek_color))

        if self.hovering == 4:
            utils.draw_points([self.point_click_seek_loc],
                              size=4*self.bar.size.y,
                              color=RGBA(*seekbar_seek_color_hover))

        # debug draggable areas
        # rect(self.seek_handle.org, self.seek_handle.size, RGBA(1., 0., 0., 0.2))
        # rect(self.trim_left_handle.org, self.trim_left_handle.size, RGBA(1., 0., 0., 0.2))
        # rect(self.trim_right_handle.org, self.trim_right_handle.size, RGBA(1., 0., 0., 0.2))

        cdef basestring current_str = '{}x'.format(self.playback_speed.value) if self.playback_speed.value else str(current_val + 1)
        cdef basestring trim_left_str = str(trim_left_val + 1)
        cdef basestring trim_right_str = str(trim_right_val + 1)

        cdef float trim_num_offset = 3. * ui_scale
        cdef float nums_y = self.play.button.org.y + self.play.button.size.y - seekbar_number_size * ui_scale / 3
        # if self.hovering or self.seeking or self.trimming_left or self.trimming_right:
        glfont.push_state()
        glfont.set_font('opensans')
        glfont.set_size(seekbar_number_size * ui_scale)

        # draw actual text
        glfont.set_blur(.1)
        glfont.set_color_float((1., 1., 1., .8))

        glfont.set_align(fs.FONS_ALIGN_TOP | fs.FONS_ALIGN_CENTER)
        # glfont.draw_text(self.seek_handle.org.x+self.seek_handle.size.x/2,
        #                  self.seek_handle.org.y+self.seek_handle.size.y + 3. * ui_scale,
        #                  current_str)
        glfont.draw_text(self.play.button.center[0], nums_y, current_str)

        glfont.set_align(fs.FONS_ALIGN_TOP | fs.FONS_ALIGN_RIGHT)
        glfont.draw_text(self.trim_left_handle.center[0] - trim_num_offset, nums_y, trim_left_str)

        glfont.set_align(fs.FONS_ALIGN_TOP | fs.FONS_ALIGN_LEFT)
        glfont.draw_text(self.trim_right_handle.center[0] + trim_num_offset, nums_y, trim_right_str)

        glfont.pop_state()

    cpdef handle_input(self,Input new_input, bint visible, bint parent_read_only = False):
        self.backwards.handle_input(new_input, True, parent_read_only=False)
        self.play.handle_input(new_input, True, parent_read_only=False)
        self.forwards.handle_input(new_input, True, parent_read_only=False)

        global should_redraw_overlay
        if self.seeking and new_input.dm:
            val = clampmap(new_input.m.x-self.bar.org.x, 0, self.bar.size.x,
                           0, self.total)
            self.current.value = int(val)
            should_redraw_overlay = True
        elif self.trimming_right and new_input.dm:
            val = clampmap(new_input.m.x-self.bar.org.x, 0, self.bar.size.x,
                           0, self.total)
            self.trim_right.value = int(val)
            should_redraw_overlay = True
        elif self.trimming_left and new_input.dm:
            val = clampmap(new_input.m.x-self.bar.org.x, 0, self.bar.size.x,
                           0, self.total)
            self.trim_left.value = int(val)
            should_redraw_overlay = True

        if self.seek_handle.mouse_over(new_input.m) or self.seeking:
            should_redraw_overlay = should_redraw_overlay or self.hovering != 1
            self.hovering = 1
        elif self.trim_right_handle.mouse_over(new_input.m) or self.trimming_right:
            should_redraw_overlay = should_redraw_overlay or self.hovering != 2
            self.hovering = 2
        elif self.trim_left_handle.mouse_over(new_input.m) or self.trimming_left:
            should_redraw_overlay = should_redraw_overlay or self.hovering != 3
            self.hovering = 3
        elif self.bar.mouse_over_margin(new_input.m, Vec2(0, 10 * ui_scale)):
            self.point_click_seek_loc = Vec2(new_input.m.x, self.bar.center[1])
            should_redraw_overlay = should_redraw_overlay or self.hovering != 4 or new_input.dm.x != 0
            self.hovering = 4
        else:
            should_redraw_overlay = should_redraw_overlay or self.hovering != 0
            self.hovering = 0


        for b in new_input.buttons[:]: # list copy for remove to work
            if b[1] == 1:
                if self.hovering == 4:
                    val = clampmap(new_input.m.x-self.bar.org.x, 0,
                                   self.bar.size.x, 0, self.total)
                    self.current.value = int(val)
                    self.hovering = 1
                    should_redraw_overlay = True

                if self.hovering == 1:
                    new_input.buttons.remove(b)
                    self.seeking = True
                    should_redraw_overlay = True
                    self.seeking_cb(True)
                elif self.hovering == 2:
                    new_input.buttons.remove(b)
                    self.trimming_right = True
                    should_redraw_overlay = True
                elif self.hovering == 3:
                    new_input.buttons.remove(b)
                    self.trimming_left = True
                    should_redraw_overlay = True

            if self.seeking and b[1] == 0:
                self.seeking = False
                should_redraw_overlay = True
                self.seeking_cb(False)
            elif self.trimming_right and b[1] == 0:
                self.trimming_right = False
                should_redraw_overlay = True
            elif self.trimming_left and b[1] == 0:
                self.trimming_left = False
                should_redraw_overlay = True


#                                 top-left   top-right  bot-right  bot-left
cdef tuple roi_corner_margins = (Vec2( roi_handle_size,  roi_handle_size),
                                 Vec2(-roi_handle_size,  roi_handle_size),
                                 Vec2(-roi_handle_size, -roi_handle_size),
                                 Vec2( roi_handle_size, -roi_handle_size))

cdef class Roi_Visualizer(UI_element):
    cdef Synced_Value display_mode, img_roi
    cdef int hovered_corner_idx, dragging
    cdef object screen_roi
    cdef Vec2 drag_offset

    def __cinit__(self, object context, *args, **kwargs):
        self.outline = FitBox(Vec2(0., 0.), Vec2(0., 0.))
        self.display_mode = Synced_Value('display_mode', context)
        self.img_roi = Synced_Value('u_r', context)
        self.hovered_corner_idx = -1
        self.dragging = -1
        self.drag_offset = Vec2(0., 0.)

    def __init__(self, *args, **kwargs):
        pass

    cpdef sync(self):
        self.display_mode.sync()
        self.img_roi.sync()

    cpdef handle_input(self,Input new_input, bint visible, bint parent_read_only = False):
        global should_redraw

        if self.display_mode.value == 'roi':
            for idx, corner, margin in zip(range(4), self.outline.corners, roi_corner_margins):
                if self.mouse_over_corner(corner, margin * ui_scale, new_input.m) or self.dragging == idx:
                    new_hovered_corner_idx = idx
                    break
            else:
                new_hovered_corner_idx = -1

            if self.hovered_corner_idx != new_hovered_corner_idx:
                self.hovered_corner_idx = new_hovered_corner_idx
                should_redraw = True

            for b in new_input.buttons[:]: # list copy for remove to work
                # left button press
                if b[0] == 0 and b[1] == 1 and self.hovered_corner_idx >= 0:
                    self.dragging = self.hovered_corner_idx
                    self.drag_offset = self.outline.corners[self.dragging] - new_input.m
                    new_input.buttons.remove(b)
                # left button release
                elif b[0] == 0 and b[1] == 0:
                    self.dragging = -1
                    new_input.buttons.remove(b)

            if self.dragging == 0:  # top left
                self.screen_roi.lX = clamp(new_input.m.x + self.drag_offset.x,
                                           0., self.screen_roi.uX - 1)
                self.screen_roi.lY = clamp(new_input.m.y + self.drag_offset.y,
                                           0., self.screen_roi.uY - 1)
                should_redraw = True
            elif self.dragging == 1:  # top right
                self.screen_roi.uX = clamp(new_input.m.x + self.drag_offset.x,
                                           self.screen_roi.lX + 1, self.screen_roi.max_shape[0] - 1)
                self.screen_roi.lY = clamp(new_input.m.y + self.drag_offset.y,
                                           0., self.screen_roi.uY - 1)
                should_redraw = True
            elif self.dragging == 2:  # bottom right
                self.screen_roi.uX = clamp(new_input.m.x + self.drag_offset.x,
                                           self.screen_roi.lX + 1,
                                           self.screen_roi.max_shape[0] - 1)
                self.screen_roi.uY = clamp(new_input.m.y + self.drag_offset.y,
                                           self.screen_roi.lY + 1,
                                           self.screen_roi.max_shape[1] - 1)
                should_redraw = True
            elif self.dragging == 3:  # bottom left
                self.screen_roi.lX = clamp(new_input.m.x + self.drag_offset.x,
                                           0., self.screen_roi.uX - 1)
                self.screen_roi.uY = clamp(new_input.m.y + self.drag_offset.y,
                                           self.screen_roi.lY + 1,
                                           self.screen_roi.max_shape[1] - 1)
                should_redraw = True

            new_roi = self.screen_roi.translate(self.img_roi.value.max_shape)
            self.img_roi.value = new_roi


    cpdef draw(self,FitBox parent,bint nested=True, bint parent_read_only = False):
        # calculate outline based on img_roi
        self.screen_roi = self.img_roi.value.translate(parent.size)
        self.outline.org = Vec2(self.screen_roi.lX, self.screen_roi.lY)
        self.outline.size = Vec2(self.screen_roi.uX - self.screen_roi.lX,
                                 self.screen_roi.uY - self.screen_roi.lY)

        # self.outline.sketch(RGBA(1., 0., 0., .1))
        cdef RGBA color = RGBA(*roi_darkening_color)

        #  +--+---+--+
        #  |A | B | C|
        #  |  +---+  |
        #  |  |ROI|  |
        #  |  +---+  |
        #  |  | D |  |
        #  +--+---+--+

        # Draw A
        rect_corners(Vec2(0., 0.), Vec2(self.outline.org.x, parent.size.y), color)

        # Draw C
        rect_corners(Vec2(self.outline.org.x + self.outline.size.x, 0.),
                     Vec2(parent.size.x, parent.size.y), color)

        # Draw B
        rect_corners(Vec2(self.outline.org.x, 0.),
                     Vec2(self.outline.org.x + self.outline.size.x,
                          self.outline.org.y), color)

        # Draw D
        rect_corners(Vec2(self.outline.org.x, self.outline.org.y + self.outline.size.y),
                     Vec2(self.outline.org.x + self.outline.size.x,
                          parent.size.y), color)

        rect_midline(self.outline.org, self.outline.size, ui_scale, RGBA(*roi_outline_color))

        if self.display_mode.value == 'roi':
            for idx, corner, margin in zip(range(4), self.outline.corners, roi_corner_margins):

                # select color
                if idx == self.hovered_corner_idx:
                    color = RGBA(*roi_outline_color_hovered)
                else:
                    color = RGBA(*roi_outline_color)

                rect(corner, margin*ui_scale, color)

    cdef mouse_over_corner(self, Vec2 corner, Vec2 margin, Vec2 m):
        lX = min(corner.x, corner.x + margin.x)
        uX = max(corner.x, corner.x + margin.x)
        lY = min(corner.y, corner.y + margin.y)
        uY = max(corner.y, corner.y + margin.y)
        return lX <= m.x <= uX and lY <= m.y <= uY
