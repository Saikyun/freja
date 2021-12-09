(import freja/state)
(import freja/events :as e)
(import freja/new_gap_buffer :as gb)
(import freja/render_new_gap_buffer :as rgb)
(import freja/theme)
(import freja/checkpoint)
(import spork/path)

(def open-files
  @{})

(defn open-file*
  [compo-state]
  (def [_ state] compo-state)
  (state/push-buffer-stack compo-state)
  (when (state :freja/focus)
    (:freja/focus state)))

(defn open-file
  [path &opt line column]

  (def abspath (path/abspath path))

  (if-let [comp-state (open-files abspath)]
    (open-file* comp-state)
    (let [new-state (state/ext->editor (path/ext path) {:path path})]
      (put open-files abspath new-state)
      (open-file* new-state)))

  (let [gb (get-in open-files [abspath :editor :gb])]
    (when line
      (rgb/goto-line-number gb line))

    (when column
      (gb/move-n gb column))))

(comment
  (open-file "freja/main.janet")
  #
  )
 