;;; test-ox-jekyll.el --- Tests for ox-jekyll.el  -*- lexical-binding: t -*-

(require 'ert)
(require 'ox-jekyll)

;; ---------------------------------------------------------------------------
(ert-deftest ox-jekyll-test-date-from-filename ()
  "Test date extraction from filename."
  ;; Standard format.
  (should (equal (org-jekyll-date-from-filename "2023-10-25-my-post.org")
                 "2023-10-25"))
  ;; With directory path.
  (should (equal (org-jekyll-date-from-filename "/path/to/2026-05-19-test.org")
                 "2026-05-19"))
  ;; No date prefix.
  (should (equal (org-jekyll-date-from-filename "my-post.org")
                 nil)))

;; ---------------------------------------------------------------------------
(ert-deftest ox-jekyll-test-src-block ()
  "Test src-block transformation to Jekyll highlight block."
  (let* ((src-block '(src-block (:language "ruby" :value "puts 'hello'\n")))
         (result (org-jekyll-src-block src-block nil nil))
         (expected "{% highlight ruby %}\n{% raw %}\nputs 'hello'\n\n{% endraw %}\n{% endhighlight %}"))
    (should (equal result expected))))

;; ---------------------------------------------------------------------------
(ert-deftest ox-jekyll-test-yaml-front-matter-published ()
  "Test YAML front matter generation with published status."
  (let* ((info (list :title "Test Post"
                     :date "2026-05-19"
                     :layout "post"
                     :categories "Emacs Lisp"
                     :published "true"
                     :exported-data (make-hash-table :test 'eq)))
         (result (org-jekyll--yaml-front-matter info)))
    (should (string-match-p "title: \"Test Post\"" result))
    (should (string-match-p "date: 2026-05-19" result))
    (should (string-match-p "layout: post" result))
    ;; Expect a trailing space after "Emacs" based on the current implementation.
    (should (string-match-p "categories: \n- Emacs \n- Lisp" result))
    (should (string-match-p "published: true" result))))

;; ---------------------------------------------------------------------------
(ert-deftest ox-jekyll-test-yaml-front-matter-preview ()
  "Test PREVIEW prefix when published is not true."
  (let* ((info (list :title "Draft Post"
                     :published "false"
                     :exported-data (make-hash-table :test 'eq)))
         (result (org-jekyll--yaml-front-matter info)))
    ;; The title must have the [PREVIEW] prefix.
    (should (string-match-p "title: \"\\[PREVIEW\\] Draft Post\"" result))
    (should (string-match-p "published: false" result))))

;; ---------------------------------------------------------------------------
(provide 'test-ox-jekyll)
;;; test-ox-jekyll.el ends here
