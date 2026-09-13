//
//  ImageGalleryViewController.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import UIKit

class ImageGalleryViewController: UIPageViewController {
    private static let pagingButtonSize: CGFloat = 44
    
    private let galleryViewModel = ImageGalleryViewModel()
    private let loadingActivityIndicator = UIActivityIndicatorView(style: .large)
    private let previousButton = UIButton(type: .system)
    private let nextButton = UIButton(type: .system)
    
    //setting a page whilst one is already on its way leaves `UIPageViewController` showing
    //one page and reporting another, so taps that land mid-transition are ignored
    private var isPaging = false
    
    // MARK: - ViewLifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        configureNavigationBar()
        configureLoadingActivityIndicator()
        configurePagingButtons()
        
        dataSource = self
        delegate = self
        
        galleryViewModel.delegate = self
        galleryViewModel.load()
    }
    
    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    private func configureLoadingActivityIndicator() {
        loadingActivityIndicator.hidesWhenStopped = true
        loadingActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(loadingActivityIndicator)
        
        NSLayoutConstraint.activate([loadingActivityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     loadingActivityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
    }
    
    private func configurePagingButtons() {
        configure(previousButton,
                  symbolName: "chevron.left",
                  accessibilityLabel: "Previous image",
                  action: #selector(previousButtonPressed))
        configure(nextButton,
                  symbolName: "chevron.right",
                  accessibilityLabel: "Next image",
                  action: #selector(nextButtonPressed))
        
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([previousButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 16),
                                     previousButton.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor),
                                     safeArea.trailingAnchor.constraint(equalTo: nextButton.trailingAnchor, constant: 16),
                                     nextButton.centerYAnchor.constraint(equalTo: safeArea.centerYAnchor)])
    }
    
    private func configure(_ button: UIButton,
                           symbolName: String,
                           accessibilityLabel: String,
                           action: Selector) {
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20,
                                                              weight: .semibold)
        
        button.setImage(UIImage(systemName: symbolName, withConfiguration: symbolConfiguration),
                        for: .normal)
        button.tintColor = .label
        button.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)
        button.layer.cornerRadius = Self.pagingButtonSize / 2
        button.accessibilityLabel = accessibilityLabel
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        
        button.addTarget(self,
                         action: action,
                         for: .touchUpInside)
        
        view.addSubview(button)
        
        NSLayoutConstraint.activate([button.widthAnchor.constraint(equalToConstant: Self.pagingButtonSize),
                                     button.heightAnchor.constraint(equalToConstant: Self.pagingButtonSize)])
    }
    
    // MARK: - Pages
    
    private var currentIndex: Int? {
        (viewControllers?.first as? ImageViewerViewController)?.index
    }
    
    private func imageViewerViewController(at index: Int) -> ImageViewerViewController? {
        guard let viewModel = galleryViewModel.viewModel(at: index) else {
            return nil
        }
        
        return ImageViewerViewController.instantiate(viewModel: viewModel, index: index)
    }
    
    private func showFirstImage() {
        guard let viewController = imageViewerViewController(at: 0) else {
            return
        }
        
        setViewControllers([viewController], direction: .forward, animated: false)
        
        bringPagingButtonsToFront()
        updatePagingControls(for: 0)
    }
    
    // MARK: - Paging
    
    @objc private func previousButtonPressed() {
        guard let currentIndex = currentIndex else {
            return
        }
        
        showImage(at: currentIndex - 1,
                  direction: .reverse)
    }
    
    @objc private func nextButtonPressed() {
        guard let currentIndex = currentIndex else {
            return
        }
        
        showImage(at: currentIndex + 1,
                  direction: .forward)
    }
    
    private func showImage(at index: Int,
                           direction: UIPageViewController.NavigationDirection) {
        guard !isPaging,
              let viewController = imageViewerViewController(at: index) else {
            return
        }
        
        isPaging = true
        
        setViewControllers([viewController], direction: direction, animated: true) { [weak self] _ in
            self?.isPaging = false
        }
        
        bringPagingButtonsToFront()
        
        //a page set in code doesn't reach `didFinishAnimating`, so landing on it has to
        //be reported here instead
        galleryViewModel.move(to: index)
        updatePagingControls(for: index)
    }
    
    private func bringPagingButtonsToFront() {
        view.bringSubviewToFront(previousButton)
        view.bringSubviewToFront(nextButton)
    }
    
    private func updatePagingControls(for index: Int) {
        title = "\(index + 1) of \(galleryViewModel.numberOfImages)"
        
        previousButton.isHidden = index == 0
        nextButton.isHidden = index >= (galleryViewModel.numberOfImages - 1)
    }
    
    private func hidePagingButtons() {
        previousButton.isHidden = true
        nextButton.isHidden = true
    }
}

extension ImageGalleryViewController: UIPageViewControllerDataSource {
    
    // MARK: - UIPageViewControllerDataSource
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let imageViewerViewController = viewController as? ImageViewerViewController else {
            return nil
        }
        
        return self.imageViewerViewController(at: imageViewerViewController.index - 1)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let imageViewerViewController = viewController as? ImageViewerViewController else {
            return nil
        }
        
        return self.imageViewerViewController(at: imageViewerViewController.index + 1)
    }
}

extension ImageGalleryViewController: UIPageViewControllerDelegate {
    
    // MARK: - UIPageViewControllerDelegate
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            willTransitionTo pendingViewControllers: [UIViewController]) {
        isPaging = true
    }
    
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        isPaging = false
        
        //Only a transition the user actually landed on should pause what came
        //before it - a cancelled swipe hasn't moved anywhere.
        guard completed,
              let imageViewerViewController = viewControllers?.first as? ImageViewerViewController else {
            return
        }
        
        galleryViewModel.move(to: imageViewerViewController.index)
        
        updatePagingControls(for: imageViewerViewController.index)
    }
}

extension ImageGalleryViewController: ImageGalleryViewModelDelegate {
    
    // MARK: - ImageGalleryViewModelDelegate
    
    func viewModel(_ viewModel: ImageGalleryViewModel,
                   didChangeTo state: ImageGalleryViewModel.State) {
        switch state {
        case .loading:
            loadingActivityIndicator.startAnimating()
            hidePagingButtons()
        case .loaded:
            loadingActivityIndicator.stopAnimating()
            showFirstImage()
        case .failed:
            loadingActivityIndicator.stopAnimating()
            //TODO: Handle error
            break
        }
    }
}
