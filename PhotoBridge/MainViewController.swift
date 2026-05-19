import UIKit

class MainViewController: UIViewController {

    private let statusLabel = UILabel()
    private let iconLabel   = UILabel()
    private let infoLabel   = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1)

        iconLabel.text = "📸"
        iconLabel.font = .systemFont(ofSize: 72)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.text = "iDevice Manager Bridge"
        statusLabel.font = .boldSystemFont(ofSize: 22)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        infoLabel.text = "Bridge đang chạy trên cổng 8765\nGiữ app này mở khi import ảnh từ PC"
        infoLabel.font = .systemFont(ofSize: 15)
        infoLabel.textColor = UIColor(white: 0.6, alpha: 1)
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false

        let dot = UIView()
        dot.backgroundColor = UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1)
        dot.layer.cornerRadius = 6
        dot.translatesAutoresizingMaskIntoConstraints = false

        let dotLabel = UILabel()
        dotLabel.text = "Active"
        dotLabel.font = .systemFont(ofSize: 13, weight: .medium)
        dotLabel.textColor = UIColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1)
        dotLabel.translatesAutoresizingMaskIntoConstraints = false

        let dotRow = UIStackView(arrangedSubviews: [dot, dotLabel])
        dotRow.axis = .horizontal
        dotRow.spacing = 6
        dotRow.alignment = .center
        dotRow.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(iconLabel)
        view.addSubview(statusLabel)
        view.addSubview(dotRow)
        view.addSubview(infoLabel)

        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),

            statusLabel.topAnchor.constraint(equalTo: iconLabel.bottomAnchor, constant: 16),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            dotRow.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            dotRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            dot.widthAnchor.constraint(equalToConstant: 12),
            dot.heightAnchor.constraint(equalToConstant: 12),

            infoLabel.topAnchor.constraint(equalTo: dotRow.bottomAnchor, constant: 20),
            infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }
}
