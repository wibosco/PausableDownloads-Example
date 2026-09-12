//
//  ImageGalleryViewController.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import UIKit

class ImageGalleryViewController: UIPageViewController {
    private let galleryViewModel = ImageGalleryViewModel()
    private let loadingActivityIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - ViewLifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        configureNavigationBar()
        configureLoadingActivityIndicator()
        
        dataSource = self
        delegate = self
        
        galleryViewModel.delegate = self
        galleryViewModel.load()
    }
    
    private func configureNavigationBar() {
        //Paging in `.scroll` style puts a scroll view behind the bar, so without
        //this it adopts its transparent scroll-edge appearance and the position
        //indicator disappears against the black background.
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
    
    // MARK: - Pages
    
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
        
        updateTitle(for: 0)
    }
    
    private func updateTitle(for index: Int) {
        title = "\(index + 1) of \(galleryViewModel.numberOfImages)"
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
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        //Only a transition the user actually landed on should pause what came
        //before it - a cancelled swipe hasn't moved anywhere.
        guard completed,
              let imageViewerViewController = viewControllers?.first as? ImageViewerViewController else {
            return
        }
        
        galleryViewModel.move(to: imageViewerViewController.index)
        
        updateTitle(for: imageViewerViewController.index)
    }
}

extension ImageGalleryViewController: ImageGalleryViewModelDelegate {
    
    // MARK: - ImageGalleryViewModelDelegate
    
    func viewModel(_ viewModel: ImageGalleryViewModel,
                   didChangeTo state: ImageGalleryViewModel.State) {
        switch state {
        case .loading:
            loadingActivityIndicator.startAnimating()
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
