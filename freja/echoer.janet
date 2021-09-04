(import freja/state)
(import freja/events :as e)
(import freja/textarea :as ta)
(use freja/defonce)
(import freja/theme :as t)
(import freja/new_gap_buffer :as gb)
(import freja/frp)
(import freja/input)

(comment
  (:toggle-console state/editor-state)

  (state/editor-state :last-right)

  (e/put! state/editor-state :right
          (state/editor-state :last-right))

  #
)

(defonce state (ta/default-textarea-state))

(defonce state-big (ta/default-textarea-state))

(def text-size 20)

(defn bottom
  [_ & _]
  [:background {:color 0x444444ff}
   [:padding {:all 2}
    [ta/textarea {:state state
                  :text/spacing 0.5
                  :text/size text-size
                  :text/font "MplusCode"
                  :text/color (t/colors :text)}]]])

(defn big
  [_ & _]
  [:background {:color 0x444444ff}
   [:padding {:all 2}
    [ta/textarea {:state state-big
                  :text/spacing 0.5
                  :text/size text-size
                  :text/font "MplusCode"
                  :text/color (t/colors :text)
                  :space-in-bottom (state/editor-state :bottom-h)}]]])

(e/put! state/editor-state
        :bottom bottom)

(put state/editor-state
     :toggle-console
     (fn [self]
       (def curr (self :right))
       (if (= curr big)
         (e/put! self :right (self :last-right))
         (-> self
             (e/put! :last-right curr)
             (e/put! :right big)))))

(e/put! state/editor-state :bottom-h 55)

(defn append
  [state s]
  (-> (state :gb)
      (gb/append-string! s)
      (gb/end-of-buffer)))

(defn replace
  [state s]
  (-> (state :gb)
      (gb/replace-content (string/trim s))
      (gb/end-of-buffer)))

(varfn handle-eval-results
  [res]
  (print "=> " (string/trim (res :code)))
  (if (res :error)
    (pp (res :error))
    (pp (res :value))))


(defn init
  []
  (frp/subscribe! frp/eval-results (fn [res] (handle-eval-results res)))

  (frp/subscribe! frp/out (partial replace state))

  (frp/subscribe! frp/out (partial append state-big)))

(import freja/default-hotkeys :as dh)

(defn toggle-console
  [_]
  (:toggle-console state/editor-state))

(defn clear-console
  [_]
  (gb/replace-content (state-big :gb) @""))

(dh/global-set-key [:control :alt :l] toggle-console)
(dh/global-set-key [:control :alt :c] clear-console)