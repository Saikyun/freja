(import freja-layout/default-tags :as dt)
(import ./new_gap_buffer :as gb)
(import ./input :as i)
(import ./collision :as c)
(import freja/theme)
(import freja/frp)
(import ./events :as e)
(import freja/state)
(import ./render_new_gap_buffer :as rgb)
(use freja-jaylib)

(use profiling/profile)

# just doing this as inlining
(defmacro press
  [kind]
  ~(do (i/handle-keyboard2
         (self :gb)
         k
         ,kind)
     (put self :event/changed true)))

(varfn text-area-on-event
  [self ev]
  (match ev
    [:key-down k]
    (press :key-down)

    [:key-repeat k]
    (press :key-repeat)

    [:key-release k]
    (press :key-release)

    [:char k]
    (do
      (i/handle-keyboard-char
        (self :gb)
        k)
      (put self :event/changed true))

    [:scroll n mp]
    (when (c/in-rec? mp
                     (i/gb-rec (self :gb)))
      (i/handle-scroll-event (self :gb) n)
      (put self :event/changed true))

    [(_ (i/mouse-events (first ev))) _]
    (i/handle-mouse-event
      (self :gb)
      ev
      (fn [kind f]
        (f)
        (state/focus! self)
        (put (self :gb) :event/changed true)))))

(varfn draw-textarea
  [self]
  (def {:gb gb} self)

  (def {:size size} gb)

  (when size
    (draw-rectangle
      0
      0
      (in size 0)
      (in size 1)
      (or (gb :background)
          (get-in gb [:colors :background])
          :blank)))

  (rgb/gb-pre-render gb)
  #  (rgb/inner-render gb)

  #(print "huh")

  (rgb/gb-render-text gb)

  (when (= self (state/focus :focus))
    (when (> 30 (gb :blink))
      (rgb/render-cursor gb))

    (update gb :blink inc) # TODO: should be dt

    (when (< 50 (gb :blink))
      (put gb :blink 0))))

(defn default-textarea-state
  [&keys {:gap-buffer gap-buffer
          :binds binds
          :on-change on-change}]
  (default gap-buffer (gb/new-gap-buffer))

  (default binds (table/setproto @{} state/gb-binds))

  (merge-into gap-buffer
              {:binds binds
               :colors theme/colors})

  (update gap-buffer :blink |(or $ 0))

  @{:gb gap-buffer

    # call like this so varfn works
    :draw (fn [self] (draw-textarea self))

    :on-event (fn [self ev]
                (text-area-on-event self ev)
                (when (and on-change
                           (get-in self [:gb :changed]))
                  (on-change (gb/content (self :gb)))))})

(defn textarea
  [props & _]
  (def {:state state
        :offset offset
        :text/color text/color
        :text/size text/size
        :text/font text/font
        :text/line-height text/line-height
        :text/spacing text/spacing
        :binds binds #replaces binds
        :extra-binds extra-binds #adds onto default binds
        :show-line-numbers show-line-numbers
        :on-change on-change} props)

  (default state (get (dyn :element) :state @{}))

  (unless (get state :gb)
    (merge-into state (default-textarea-state
                        :on-change on-change
                        :binds binds
                        :extra-binds extra-binds)))

  (when extra-binds
    (put (state :gb)
         :binds
         (-> (merge-into @{} extra-binds)
             (table/setproto state/gb-binds))))

  (default offset (if show-line-numbers
                    [12 0]
                    [12 0]))
  (default text/size (dyn :text/size 14))
  (default text/font (dyn :text/font "Poppins"))
  (default text/line-height (dyn :text/line-height 1))
  (default text/spacing (dyn :text/spacing 1))
  (default text/color (dyn :text/color 0x000000ff))

  (put-in state [:gb :text/size] text/size)
  (put-in state [:gb :text/font] text/font)
  (put-in state [:gb :text/line-height] text/line-height)
  (put-in state [:gb :text/spacing] text/spacing)
  (put-in state [:gb :text/color] text/color)
  (put-in state [:gb :changed] true)
  (put-in state [:gb :show-line-numbers] show-line-numbers)
  (put-in state [:gb :offset] offset)

  (-> (dyn :element)
      (dt/add-default-props props)
      (put :state state)
      (merge-into
        @{:children []
          :relative-sizing
          (fn [el max-width max-height]
            # (print "resizing text area " max-width " " max-height)
            # TODO: something strange happens when width / height is too small
            # try removing 50 then resize to see
            (-> el
                (put :width (max 50 (or (el :preset-width) max-width)))
                (put :height (max (get-in state [:gb :conf :size] 0)
                                  (or (el :preset-height) max-height)))
                (put :content-width (el :width))
                (put :layout/lines nil))

            (def [old-w old-h] (get-in state [:gb :size]))

            (unless (and (= old-w (el :width))
                         (= old-h (el :height)))
              (put-in state [:gb :size]
                      [(math/floor (el :width))
                       (math/floor (el :height))])
              (put-in state [:gb :changed] true)
              (put-in state [:gb :resized] true))

            # (print "el: " (el :width) " / " (el :height))

            el)

          :render (fn [self parent-x parent-y]
                    (:draw state))

          :on-event (fn [self ev]
                      #(pp self)
                      #(print "start " (state :id))

                      #(tracev [(dyn :offset-x) (dyn :offset-y)])

                      (defn update-pos
                        [[x y]]
                        [(- x
                            (dyn :offset-x 0))
                         (- y
                            (dyn :offset-y 0))])

                      (def new-ev (if (= (first ev) :scroll)
                                    [(ev 0)
                                     (ev 1)
                                     (update-pos (ev 2))]
                                    [(ev 0)
                                     (update-pos (ev 1))]))

                      #(text-area-on-event state new-ev)
                      (:on-event state new-ev)

                      (when (and on-change
                                 (get-in state [:gb :changed]))
                        (on-change (gb/content (state :gb))))

                      (def pos (new-ev
                                 (if (= :scroll (first new-ev))
                                   2
                                   1)))

                      (when (dt/in-rec? pos
                                        0
                                        0
                                        (self :width)
                                        (self :height))
                        true))})))
