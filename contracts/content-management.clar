;; Content Management Contract
;; Manages knowledge articles and content

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-ARTICLE-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INPUT (err u202))
(define-constant ERR-ARTICLE-EXISTS (err u203))
(define-constant ERR-INVALID-CATEGORY (err u204))

;; Data Variables
(define-data-var next-article-id uint u1)
(define-data-var total-articles uint u0)
(define-data-var next-category-id uint u1)

;; Data Maps
(define-map articles
  { article-id: uint }
  {
    title: (string-ascii 100),
    content-hash: (string-ascii 64),
    author-id: uint,
    category-id: uint,
    created-block: uint,
    updated-block: uint,
    version: uint,
    is-published: bool,
    view-count: uint,
    rating: uint
  }
)

(define-map categories
  { category-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    article-count: uint,
    is-active: bool
  }
)

(define-map article-tags
  { article-id: uint, tag: (string-ascii 30) }
  { exists: bool }
)

(define-map article-versions
  { article-id: uint, version: uint }
  {
    content-hash: (string-ascii 64),
    updated-by: uint,
    updated-block: uint,
    change-notes: (string-ascii 200)
  }
)

;; Public Functions

;; Create a new category
(define-public (create-category (name (string-ascii 50)) (description (string-ascii 200)))
  (let
    (
      (category-id (var-get next-category-id))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)

    (map-set categories
      { category-id: category-id }
      {
        name: name,
        description: description,
        article-count: u0,
        is-active: true
      }
    )

    (var-set next-category-id (+ category-id u1))

    (ok category-id)
  )
)

;; Create a new article
(define-public (create-article
  (title (string-ascii 100))
  (content-hash (string-ascii 64))
  (author-id uint)
  (category-id uint)
)
  (let
    (
      (article-id (var-get next-article-id))
      (category (unwrap! (map-get? categories { category-id: category-id }) ERR-INVALID-CATEGORY))
    )
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len content-hash) u0) ERR-INVALID-INPUT)

    (map-set articles
      { article-id: article-id }
      {
        title: title,
        content-hash: content-hash,
        author-id: author-id,
        category-id: category-id,
        created-block: block-height,
        updated-block: block-height,
        version: u1,
        is-published: false,
        view-count: u0,
        rating: u0
      }
    )

    (map-set article-versions
      { article-id: article-id, version: u1 }
      {
        content-hash: content-hash,
        updated-by: author-id,
        updated-block: block-height,
        change-notes: "Initial version"
      }
    )

    (map-set categories
      { category-id: category-id }
      (merge category { article-count: (+ (get article-count category) u1) })
    )

    (var-set next-article-id (+ article-id u1))
    (var-set total-articles (+ (var-get total-articles) u1))

    (ok article-id)
  )
)

;; Update article content
(define-public (update-article
  (article-id uint)
  (new-content-hash (string-ascii 64))
  (editor-id uint)
  (change-notes (string-ascii 200))
)
  (let
    (
      (article (unwrap! (map-get? articles { article-id: article-id }) ERR-ARTICLE-NOT-FOUND))
      (new-version (+ (get version article) u1))
    )
    (asserts! (> (len new-content-hash) u0) ERR-INVALID-INPUT)

    (map-set articles
      { article-id: article-id }
      (merge article {
        content-hash: new-content-hash,
        updated-block: block-height,
        version: new-version
      })
    )

    (map-set article-versions
      { article-id: article-id, version: new-version }
      {
        content-hash: new-content-hash,
        updated-by: editor-id,
        updated-block: block-height,
        change-notes: change-notes
      }
    )

    (ok true)
  )
)

;; Publish article
(define-public (publish-article (article-id uint))
  (let
    (
      (article (unwrap! (map-get? articles { article-id: article-id }) ERR-ARTICLE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

    (map-set articles
      { article-id: article-id }
      (merge article { is-published: true })
    )

    (ok true)
  )
)

;; Add tag to article
(define-public (add-article-tag (article-id uint) (tag (string-ascii 30)))
  (begin
    (asserts! (is-some (map-get? articles { article-id: article-id })) ERR-ARTICLE-NOT-FOUND)
    (asserts! (> (len tag) u0) ERR-INVALID-INPUT)

    (map-set article-tags
      { article-id: article-id, tag: tag }
      { exists: true }
    )

    (ok true)
  )
)

;; Increment view count
(define-public (increment-view-count (article-id uint))
  (let
    (
      (article (unwrap! (map-get? articles { article-id: article-id }) ERR-ARTICLE-NOT-FOUND))
    )
    (map-set articles
      { article-id: article-id }
      (merge article { view-count: (+ (get view-count article) u1) })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get article by ID
(define-read-only (get-article (article-id uint))
  (map-get? articles { article-id: article-id })
)

;; Get category by ID
(define-read-only (get-category (category-id uint))
  (map-get? categories { category-id: category-id })
)

;; Get article version
(define-read-only (get-article-version (article-id uint) (version uint))
  (map-get? article-versions { article-id: article-id, version: version })
)

;; Check if article has tag
(define-read-only (has-article-tag (article-id uint) (tag (string-ascii 30)))
  (is-some (map-get? article-tags { article-id: article-id, tag: tag }))
)

;; Get total articles
(define-read-only (get-total-articles)
  (var-get total-articles)
)
