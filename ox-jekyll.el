;;; ox-jekyll.el --- Export Jekyll articles using org-mode.

;; Copyright (C) 2013-2017  Yoshinari Nomura
;;               2019 Youhei SASAKI

;; Author: Youhei SASAKI <uwabami@gfd-dennou.org>
;; Keywords: org, jekyll
;; Version: 0.1.1
;; Original: https://github.com/yoshinari-nomura/org-octopress
;;           by Yoshinari Nomura <nom@quickhack.net>

;; This is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This library implements a Jekyll-style html backend for
;; Org exporter, based on `html' back-end.
;;
;; It provides two commands for export, depending on the desired
;; output: `org-jekyll-export-as-html' (temporary buffer) and
;; `org-jekyll-export-to-html' ("html" file with YAML front matter).
;;
;; For publishing, `org-jekyll-publish-to-html' is available.
;; For composing, `org-jekyll-insert-export-options-template' is available.

;;; Code:

;;; Dependencies

(require 'ox-html)

;;; User Configurable Variables

(defgroup org-export-jekyll nil
  "Options for exporting Org mode files to jekyll HTML."
  :tag "Org Export Jekyll"
  :group 'org-export
  :version "24.2")

(defcustom org-jekyll-layout "post"
  "Default layout used in Jekyll article."
  :group 'org-export-jekyll
  :type 'string)

(defcustom org-jekyll-categories ""
  "Default space-separated categories in Jekyll article."
  :group 'org-export-jekyll
  :type 'string)

(defcustom org-jekyll-tags ""
  "Default space-separated tags in Jekyll article."
  :group 'org-export-jekyll
  :type 'string)

(defcustom org-jekyll-published "true"
  "Default publish status in Jekyll article."
  :group 'org-export-jekyll
  :type 'string)

(defcustom org-jekyll-comments ""
  "Default comments (disqus) flag in Jekyll article."
  :group 'org-export-jekyll
  :type 'string)

;;; Define Back-End

(org-export-define-derived-backend 'jekyll 'html
  :menu-entry
  '(?j "Jekyll: export to HTML with YAML front matter."
       ((?H "As HTML buffer" org-jekyll-export-as-html)
        (?h "As HTML file" org-jekyll-export-to-html)))
  :translate-alist
  '((template . org-jekyll-template) ;; add YAML front matter.
    (src-block . org-jekyll-src-block)
    (inner-template . org-jekyll-inner-template)) ;; force body-only
  :options-alist
  '((:lang "LANG" nil nil)
    (:ref "REF" nil nil)
    (:permalink "PERMALINK" nil nil)
    (:layout "LAYOUT" nil org-jekyll-layout)
    (:categories "CATEGORIES" nil org-jekyll-categories)
    (:tags "TAGS" nil org-jekyll-tags)
    (:published "PUBLISHED" nil org-jekyll-published)
    (:comments "COMMENTS" nil org-jekyll-comments)))


;;; Internal Filters
(defun org-jekyll-src-block (src-block contents info)
  "Transcode SRC-BLOCK element into jekyll code template format
if `org-jekyll-use-src-plugin` is t. Otherwise, perform as
`org-html-src-block`. CONTENTS holds the contents of the item.
INFO is a plist used as a communication channel."
  (let ((language (org-element-property :language src-block))
        (value (org-remove-indentation
                (org-element-property :value src-block))))
    (format "{%% codeblock lang:%s %%}\n%s{%% endcodeblock %%}"
            language value)))

;;; Template
(defun org-jekyll-template (contents info)
  "Return complete document string after HTML conversion.
CONTENTS is the transcoded contents string. INFO is a plist
holding export options."
  (concat (org-jekyll--yaml-front-matter info) contents))

(defun org-jekyll-inner-template (contents info)
  "Return body of document string after HTML conversion.
CONTENTS is the transcoded contents string.  INFO is a plist
holding export options."
  (concat
   ;; Table of contents.
   (let ((depth (plist-get info :with-toc)))
     (when depth (org-html-toc depth info)))
   ;; PREVIEW mark on the top of article.
   (unless (equal "true" (plist-get info :published))
     "<span style=\"background: red;\">PREVIEW</span>")
   ;; Document contents.
   contents
   ;; Footnotes section.
   (org-html-footnote-section info)))

;;; YAML Front Matter
(defun org-jekyll--get-option (info property-name &optional default)
  (let ((property (org-export-data (plist-get info property-name) info)))
    (format "%s" (or property default ""))))

(defun org-jekyll--yaml-front-matter (info)
  (let ((title
         (org-jekyll--get-option info :title))
        (date
         (org-jekyll--get-option info :date))
        (lang
         (org-jekyll--get-option info :lang))
        (ref
         (org-jekyll--get-option info :ref))
        (permalink
         (org-jekyll--get-option info :permalink))
        (layout
         (org-jekyll--get-option info :layout org-jekyll-layout))
        (categories
         (org-jekyll--get-option info :categories org-jekyll-categories))
        (tags
         (org-jekyll--get-option info :tags org-jekyll-tags))
        (published
         (org-jekyll--get-option info :published org-jekyll-published))
        (comments
         (org-jekyll--get-option info :comments))
        (convert-to-yaml-list
         (lambda (arg)
           (mapconcat #'(lambda (text)(concat "\n- " text))
                      (split-string arg) " "))))
    (unless (equal published "true")
      (setq title (concat "[PREVIEW] " title)))
    (concat
     "---"
     "\ntitle: \""    title
     "\"\ndate: "     date
     "\nlang: "       lang
     "\nlayout: "     layout
     "\nref: "        ref
     "\npermalink: "  permalink
     "\ncategories: " (funcall convert-to-yaml-list  categories)
     "\ntags: "       (funcall convert-to-yaml-list tags)
     "\npublished: "  published
     "\ncomments: "   comments
     "\n---\n")))

;;; Filename and Date Helper

(defun org-jekyll-date-from-filename (&optional filename)
  (let ((fn (file-name-nondirectory (or filename (buffer-file-name)))))
    (if (string-match "^[0-9]+-[0-9]+-[0-9]+" fn)
        (match-string 0 fn)
      nil)))

(defun org-jekyll-property-list (&optional filename)
  (let ((backend 'jekyll) plist)
    (if filename
        (with-temp-buffer
          (insert-file-contents filename)
          (org-mode)
          (setq plist (org-export-get-environment backend))
          (setq plist (plist-put plist :input-file filename)))
      (setq plist (org-export-backend-options backend))
      plist)))

(defun org-jekyll-property (keys &optional filename)
  (let ((plist (org-jekyll-property-list filename)))
    (mapcar (lambda (key)
              (let ((value (plist-get plist key)))
                (setq value (if (listp value) (car value) value))
                (if (stringp value)
                    (substring-no-properties value))))
            keys)))

(defun org-jekyll-date-from-property (&optional filename)
  (let ((plist (org-jekyll-property filename)))
    (org-read-date
     nil nil
     (org-export-data-with-backend (plist-get plist :date) 'jekyll plist))))

(defun org-jekyll-create-filename ()
  (let ((date (org-jekyll-date-from-property))
        (file (file-name-nondirectory (buffer-file-name)))
        (dir  (file-name-directory (buffer-file-name))))
    (expand-file-name
     (replace-regexp-in-string "^[0-9]+-[0-9]+-[0-9]+" date file)
     dir)))

;;; End-User functions

;;;###autoload
(defun org-jekyll-export-as-html
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to a HTML buffer adding some YAML front matter."
  (interactive)
  (if async
      (org-export-async-start
          (lambda (output)
            (with-current-buffer
                (get-buffer-create "*Org Jekyll HTML Export*")
              (erase-buffer)
              (insert output)
              (goto-char (point-min))
              (funcall org-html-display-buffer-mode)
              (org-export-add-to-stack (current-buffer) 'jekyll)))
        `(org-export-as 'jekyll
                        ,subtreep
                        ,visible-only
                        ,body-only
                        ',ext-plist))
    (let ((outbuf (org-export-to-buffer
                   'jekyll "*Org Jekyll HTML Export*"
                   nil subtreep visible-only body-only ext-plist)))
      ;; Set major mode.
      (with-current-buffer outbuf (set-auto-mode t))
      (when org-export-show-temporary-export-buffer
        (switch-to-buffer-other-window outbuf)))))

;;;###autoload
(defun org-jekyll-export-to-html
  (&optional async subtreep visible-only body-only ext-plist)
  "Export current buffer to a HTML file adding some YAML front matter."
  (interactive)
  (let* ((extension (concat "." org-html-extension))
         (file (org-export-output-file-name extension subtreep))
         (org-export-coding-system org-html-coding-system))
    (if async
        (org-export-async-start
            (lambda (f) (org-export-add-to-stack f 'jekyll))
          (let ((org-export-coding-system org-html-coding-system))
            `(expand-file-name
              (org-export-to-file
                  'jekyll
                  ,file nil
                  ,subtreep
                  ,visible-only
                  ,body-only
                  ',ext-plist))))
      (let ((org-export-coding-system org-html-coding-system))
        (org-export-to-file
            'jekyll file nil subtreep visible-only body-only ext-plist)))))

;;;###autoload
(defun org-jekyll-publish-to-html (plist filename pub-dir)
  "Publish an org file to HTML with YAML front matter.

FILENAME is the filename of the Org file to be published.  PLIST
is the property list for the given project.  PUB-DIR is the
publishing directory.

Return output file name."
  (org-publish-org-to 'jekyll filename ".html" plist pub-dir))

;; ;;;###autoload
;; (defun org-jekyll-insert-export-options-template
;;     (&optional title date lang ref permalink categories tags published layout)
;;   "Insert a settings template for Jekyll exporter."
;;   (interactive)
;;   (let ((layout     (or layout org-jekyll-layout))
;;         (published  (or published org-jekyll-published))
;;         (tags       (or tags org-jekyll-tags))
;;         (categories (or categories org-jekyll-categories)))
;;     (save-excursion
;;       (insert (format (concat
;;                        "#+TITLE: "        title
;;                        "\n#+DATE: "       date
;;                        "\n#+SETUPFILE: "  setupfile
;;                        "\n#+LAYOUT: "     layout
;;                        "\n#+CATEGORIES: " categories
;;                        "\n#+TAGS: "       tags
;;                        "\n#+PUBLISHED: "  published
;;                        "\n\n* \n\n{{{more}}}"))))))
;;; provide

(provide 'ox-jekyll)

;;; ox-jekyll.el ends here
