var path = require('path');
var webpack = require('webpack');

module.exports = {
  devtool: 'cheap-module-eval-source-map',
  entry: [
    'webpack-hot-middleware/client',
    './src/main'
  ],
  output: {
    path: path.join(__dirname, 'dist'),
    filename: 'bundle.js',
    publicPath: '/static/'
  },
  plugins: [
    new webpack.HotModuleReplacementPlugin()
  ],
  resolve: {
    extensions: ['', '.js', '.coffee'],
    alias: {
      'oublie': path.join(__dirname, '../../src')
    }
  },
  module: {
    loaders: [{
      test: /\.js$/,
      loaders: ['react-hot', 'babel'],
      include: path.join(__dirname, 'src')
    },
    {
      test: /\.coffee?$/,
      loaders: ['babel', 'coffee-loader'],
      include: [
        path.join(__dirname, '../../src')
      ]
    },
    {
      test: /\.coffee?$/,
      loaders: ['react-hot', 'babel', 'coffee-loader'],
      include: [
        path.join(__dirname, 'src')
      ]
    },
    { test: /\.css$/, loader: "style-loader!css-loader" }
    ]
  }
};
